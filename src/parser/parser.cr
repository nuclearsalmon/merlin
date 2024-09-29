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
      #validate_references_existance
      #detect_and_fix_left_recursive_rules
      #detect_unused_tokens
      #detect_unused_groups
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
            puts "#{padding}failed #{directive.group.name}"
            # remove as we're done with this directive
            @parsing_queue.pop()
            @parsing_position = directive.started_at

            @parsing_queue.empty? ? break : next
          else
            # success, add to context
            context = directive.context
            if directive.pattern.size > 1
              context.add(target_ident, token)
            else
              context.add(token)
            end
          end
        else
          # group
          group_context = expect_group(target_ident)

          if group_context.nil?
            next
          else
            context = directive.context
            if directive.pattern.size > 1
              context.unsafe_add(target_ident, group_context)
            else
              context.unsafe_merge(group_context)
            end
          end
        end

        # assign next target
        unless directive.done?
          directive.advance
        end
        if directive.done?
          # handle trailing ignores
          trailing_ignores = directive.group.trailing_ignores
          unless trailing_ignores.nil?
            next_token(trailing_ignores)
            # step back so next call can get the not-ignored token
            @parsing_position -= 1
          end

          # remove as we're done with this directive
          @parsing_queue.pop()

          # execute block on context
          block = directive.rule.block
          block.call(directive.context) unless block.nil?

          # save to cache
          @cache.store(
            ident:            directive.name,
            context:          directive.context,
            start_position:   directive.started_at,
            parsing_position: @parsing_position
          )
        end

        pp @parsing_queue

        if @parsing_queue.empty?
          puts "#{padding}empty"
          break directive.context?.try(&.node)
        end
      end
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

    private def expect_group(ident : IdentT) : Context(IdentT, NodeT)?
      # try the cache
      cached_context = expect_cache(ident)

      if cached_context.nil?
        # increment for next step
        next_directive = @parsing_queue[-1]
        if next_directive.done?
          @parsing_queue.pop()
        else
          next_directive.advance
        end

        # mark for parsing
        @parsing_queue << Directive(IdentT, NodeT).new(
          @parsing_position,
          @groups[ident]
        )
      end
      return cached_context
    end

    # a a b -> (a) (a b) x
    # a a b a a b -> ((a) (a b)) (a) (a b) x
    # group :as
    #   rule :as, :a, :b
    #   rule :a
    # end
  end
end
