module Merlin
  class Parser(IdentT, NodeT)
    include Tokenizer(IdentT)
    include ParserValidator(IdentT, NodeT)

    property reference_recursion_limit : Int32 = 1024

    # parser configuration
    # ---

    @root : Group(IdentT, NodeT)
    @groups : Hash(IdentT, Group(IdentT, NodeT))
    @tokens : Hash(IdentT, Token(IdentT))

    # parsing state
    # ---

    @parsing_position : Int32 = 0
    @parsing_tokens = Array(MatchedToken(IdentT)).new
    @parsing_context : Context(IdentT, NodeT)? = nil
    @parsing_queue = Array(Directive(IdentT, NodeT)).new

    # group cache
    @cache = Cache(IdentT, NodeT).new

    def initialize(
      @root : Group(IdentT, NodeT),
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

      # set initial marker
      @parsing_queue << Directive(IdentT, NodeT).new(0, @root)

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

    private def do_parse : NodeT?
      loop do
        step = @parsing_queue.size
        padding = "#{step}#{" " * step}"

        # get directive target
        directive = @parsing_queue[-1]
        target_ident = directive.target_ident
        computed_ignores = directive.group.computed_ignores

        puts "#{padding}trying #{directive.target_ident}"

        # handle target
        if Util.upcase?(target_ident)
          # token
          token_directive = @tokens[target_ident]
          token = expect_token(token_directive, computed_ignores)

          if token.nil?
            puts "#{padding}failed #{directive.target_ident}"
            directive.reset_context  # FIXME: this may break lr
            #@parsing_queue.each{|e|puts e.to_s}

            # remove as we're done with this directive
            # try next rule
            directive.next_rule
            puts "#{padding}next A: #{directive.to_s}"

            # remove fails from queue
            loop_directive = directive  # NOTE: reassigned to avoid a shotgun blast to ones own feet
            break if (loop do
              if loop_directive.done?
                @parsing_queue.pop()

                if @parsing_queue.empty?
                  break true  # inner loop control
                else
                  loop_directive = @parsing_queue[-1]
                  loop_directive.next_rule(error: false)
                  puts "#{padding}next B: #{loop_directive.to_s}"
                end
              else
                break false  # inner loop control
              end
            end)

            puts "setting #{@parsing_position} to #{loop_directive.started_at}"
            @parsing_position = loop_directive.started_at
            next  # outer loop control
          else
            # success, add to context
            directive.add(target_ident, token)
            directive.next_target
          end
        else
          # group
          cached_context = expect_cache(target_ident)

          puts "cached #{target_ident} returned #{cached_context.pretty_inspect}" if cached_context

          if cached_context.nil?
            directive.next_target  # ?
            @parsing_queue << Directive(IdentT, NodeT).new(
              @parsing_position,
              @groups[target_ident]
            )
            next
          else
            puts "#{padding}matched #{target_ident}"

            directive.add(
              target_ident,
              cached_context
            )
            directive.next_target
          end
        end

        loop_directive = directive
        while loop_directive.done?
          puts "#{padding}matched #{loop_directive.name}"
          if (q = @parsing_queue[-2..]?).nil?
            puts @parsing_queue[-1].to_s
          else
            q.each{|e|puts e.to_s}
          end

          # handle trailing ignored tokens
          consume_trailing(directive.group.trailing_ignores)

          # execute block on context
          block = loop_directive.rule.block
          block.call(loop_directive.context) unless block.nil?

          # save to cache
          @cache.store(
            ident:            loop_directive.name,
            context:          loop_directive.context,
            start_position:   loop_directive.started_at,
            parsing_position: @parsing_position
          )

          # remove as we're done with this directive
          @parsing_queue.pop()


          parent_directive = @parsing_queue[-1]?
          break if parent_directive.nil?

          # give to parent directive
          parent_directive.add(
            loop_directive.name,
            loop_directive.context
          )

          # assign next directive
          loop_directive = parent_directive
        end

        if @parsing_queue.empty?
          break loop_directive.context?.try(&.result)
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

    # a a b -> (a) (a b) x
    # a a b a a b -> ((a) (a b)) (a) (a b) x
    # group :as
    #   rule :as, :a, :b
    #   rule :a
    # end
  end
end
