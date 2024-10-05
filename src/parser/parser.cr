module Merlin
  class Parser(IdentT, NodeT)
    include Tokenizer(IdentT)
    include ParserValidator(IdentT, NodeT)

    property reference_recursion_limit : Int32 = 1024

    # parser configuration
    # ---

    @root   : Group(IdentT, NodeT)
    @groups : Hash(IdentT, Group(IdentT, NodeT))
    @tokens : Hash(IdentT, Token(IdentT))

    # parsing state
    # ---

    @parsing_position : Int32 = 0
    @parsing_tokens   = Array(MatchedToken(IdentT)).new
    @parsing_queue    = Array(Directive(IdentT, NodeT)).new
    @cache            = Cache(IdentT, NodeT).new

    def initialize(
      @root   : Group(IdentT, NodeT),
      @groups = Hash(IdentT, Group(IdentT, NodeT)).new,
      @tokens = Hash(IdentT, Token(IdentT)).new
    )
      validate_references_existance
      detect_and_fix_left_recursive_rules
      detect_unused_tokens
      detect_unused_groups
    end

    def parse(@parsing_tokens : Array(MatchedToken(IdentT))) : NodeT
      # clear before parsing
      @parsing_position = 0
      @cache.clear()
      @parsing_queue.clear()

      # set initial marker
      @parsing_queue << Directive(IdentT, NodeT).new(
        started_at:      0,
        group:           @root,
        lr:              false,
        current_ignores: compute_new_ignores(nil, @root)
      )

      # parse
      result_node = do_parse

      if result_node.nil?
        raise Error::BadInput.new("Parsing failed to match anything.")
      end

      # verify that every token was consumed
      position = @parsing_position
      if position < @parsing_tokens.size
        Log.debug {
          "Got #{result_node.pretty_inspect}, but only matched " +
          "#{position}/#{@parsing_tokens.size} tokens."
        }
        raise Error::UnexpectedCharacter.new(
          @parsing_tokens[position].value[0],
          @parsing_tokens[position].position)
      end

      # done parsing
      result_node
    end

    private def generate_log_padding
      step = @parsing_queue.size
      "#{step}#{" " * step}"
    end

    private def do_parse : NodeT?
      loop do
        padding = generate_log_padding

        # get directive target
        directive = @parsing_queue[-1]
        target_ident = directive.target_ident

        # handle current directive target
        if Util.upcase?(target_ident)
          # token
          token_directive = @tokens[target_ident]
          token = expect_token(token_directive, directive.current_ignores)

          if token.nil?
            puts "#{padding}failed :#{directive.target_ident}"
            directive.reset_context  # FIXME: this may break lr
            #@parsing_queue.each{|e|puts e.to_s}

            # remove as we're done with this directive
            # try next rule
            directive.next_rule
            #puts "#{padding}next A: #{directive.to_s}"

            # remove fails from queue
            skip = (loop do
              if directive.done?
                @parsing_queue.pop()

                if @parsing_queue.empty?
                  return nil
                else
                  next_directive = @parsing_queue[-1]
                  #puts "#{padding}dir     : #{directive.to_s}"
                  #puts "#{padding}next_dir: #{next_directive.to_s}"
                  if directive.lr? && next_directive.done?
                    #puts "setting #{@parsing_position} to #{directive.started_at}"
                    @parsing_position = directive.started_at

                    directive = next_directive
                    break false  # inner loop control
                  else
                    directive = next_directive
                    directive.next_rule(error: false)
                  end
                end
              else
                #puts "setting #{@parsing_position} to #{directive.started_at}"
                @parsing_position = directive.started_at

                break true  # inner loop control
              end
            end)

            next if skip
          else
            # success, add to context
            puts "#{padding}matched :#{directive.target_ident}"
            directive.add(target_ident, token)
            directive.next_target
          end
        else
          # group
          cached_context = expect_cache(target_ident)

          if cached_context.nil?
            puts "#{padding}trying :#{directive.target_ident}"
            directive.next_target  # ?
            new_ignores = compute_new_ignores(directive.current_ignores, @groups[target_ident])
            @parsing_queue << Directive(IdentT, NodeT).new(
              started_at:      @parsing_position,
              group:           @groups[target_ident],
              lr:              false,
              current_ignores: new_ignores
            )
            next
          else
            puts "#{padding}matched :#{target_ident} from cache: #{cached_context.pretty_inspect}"

            directive.add(
              target_ident,
              cached_context
            )
            directive.next_target
          end
        end

        # handle result
        while directive.done?
          puts "#{padding}matched :#{directive.name}"
          #if (q = @parsing_queue[-2..]?).nil?
          #  puts @parsing_queue[-1].to_s
          #else
          #  q.each{|e|puts e.to_s}
          #end

          #puts "==="
          #puts directive.pretty_inspect

          # handle trailing ignored tokens
          consume_trailing(directive.group.trailing_ignores)

          # check if parent is lr
          parent_directive = @parsing_queue[-2]?
          unless parent_directive.nil?
            if parent_directive.have_tried_lr?
              #puts "directive ctx: #{directive.context.pretty_inspect}"
              #puts "directive ident: #{parent_directive.target_ident}"
              #puts "parent_directive (before): #{parent_directive.pretty_inspect}"

              # inject into parent
              parent_context = parent_directive.context
              parent_context.subcontext_self(
                parent_directive.name.not_nil!
              )
              parent_context.merge(
                directive.context
              )

              # replace context with parent context
              directive.context = parent_context

              # set store position
              directive.store_at = parent_directive.started_at

              #puts "parent_directive ctx (after): #{parent_directive.context.pretty_inspect}"
              #puts "queue: #{@parsing_queue.pretty_inspect}"

              # remove parent directive from queue
              @parsing_queue.delete_at(-2)
            end
          end

          # execute block on context
          block = directive.rule.block
          unless block.nil?
            block.call(directive.context)
            #puts "directive #{directive.name} after block call: #{directive.context.pretty_inspect}"
          end

          #pp directive

          if !directive.have_tried_lr? && directive.can_switch_to_lr?
            # save to cache
            # FIXME: should store? not sure. commenting it out fixes shit.
            #@cache.store(
            #  ident:            directive.name,
            #  context:          directive.context.clone,  # safe
            #  start_position:   directive.store_at,
            #  parsing_position: @parsing_position
            #)

            # switch to lr
            directive.have_tried_lr = true
            @parsing_queue << Directive(IdentT, NodeT).new(
              started_at:      @parsing_position,
              group:           directive.group,
              lr:              true,
              current_ignores: directive.current_ignores
            )

            # stop result loop
            break
          else
            # save to cache
            @cache.store(
              ident:            directive.name,
              context:          directive.context,  # unsafe
              start_position:   directive.store_at,
              parsing_position: @parsing_position
            )

            # remove as we're done with this directive
            @parsing_queue.pop()

            # check if there's a parent directive
            if (parent_directive = @parsing_queue[-1]?).nil?
              return directive.context.result
            else
              # give to parent directive
              parent_directive.add(
                directive.name,
                directive.context
              )
            end

            # assign next directive
            directive = parent_directive
          end
        end
      end
    end

    private def consume_trailing(
      trailing_ignores : Array(IdentT)?
    ) : Nil
      return if trailing_ignores.nil?

      # consume all
      next_token(trailing_ignores)
      # step back so next call can get the not-ignored token
      @parsing_position -= 1
    end

    private def next_token(
      computed_ignores : Array(IdentT)?
    ) : MatchedToken(IdentT)?
      loop do
        token = @parsing_tokens[@parsing_position]?
        @parsing_position += 1
        if token.nil? || computed_ignores.nil? || !(computed_ignores.includes?(token.name))
          return token
        end
      end
      return nil
    end

    private def expect_token(
      token_directive : Token(IdentT),
      computed_ignores : Array(IdentT)?
    ) : MatchedToken(IdentT)?
      initial_parsing_position = @parsing_position
      token = next_token(computed_ignores)

      # test if token matches expectation
      if !(token.nil?) && token.name != token_directive.name
        # failed, try to adapt
        if !(token_directive.adaptive && token_directive.pattern.match(token.value))
          # failed, reset position
          @parsing_position = initial_parsing_position
          return nil  # nothing matched
        end
      end
      return token  # can be nil, a name-matched token, or an adapted token
    end

    private def expect_cache(ident : IdentT) : Context(IdentT, NodeT)?
      cached = @cache[@parsing_position, ident]

      unless cached.nil?
        @parsing_position += cached[:nr_of_tokens]
        return cached[:context].clone
      end
    end

    private def compute_new_ignores(
      current_ignores : Array(IdentT)?, 
      group : Group(IdentT, NodeT)
    ) : Array(IdentT)
      new_ignores = current_ignores.nil? ? [] of IdentT : current_ignores.dup

      # Remove noignores
      unless (group_noignores = group.noignores).nil?
        new_ignores.reject! { |ig| group_noignores.includes?(ig) }
      end

      # Add ignores
      unless (group_ignores = group.ignores).nil?
        new_ignores.concat(group_ignores)
      end

      new_ignores.uniq!
      new_ignores
    end

    # a a b -> (a) (a b) x
    # a a b a a b -> ((a) (a b)) (a) (a b) x
    # group :as
    #   rule :as, :a, :b
    #   rule :a
    # end
  end
end
