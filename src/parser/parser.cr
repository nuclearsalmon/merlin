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
    @longest_token_name_size : Int32

    # parsing state
    # ---

    @parsing_position : Int32 = 0
    @parsing_tokens = Array(MatchedToken(IdentT)).new
    @parsing_queue = Array(Directive(IdentT, NodeT)).new
    @cache = Cache(IdentT, NodeT).new

    def initialize(
      @root : Group(IdentT, NodeT),
      @groups = Hash(IdentT, Group(IdentT, NodeT)).new,
      @tokens = Hash(IdentT, Token(IdentT)).new
    )
      @longest_token_name_size = @tokens.values.map(&.name.to_s.size).max
      validate_references_existance
      detect_and_fix_left_recursive_rules
      detect_unused_tokens
      detect_unused_groups
    end

    def parse(@parsing_tokens : Array(MatchedToken(IdentT))) : NodeT
      # clear before parsing
      @parsing_position = 0
      @cache.clear
      @parsing_queue.clear

      # set initial marker
      initial_ignores = compute_new_ignores(nil, @root)
      initial_trailing_ignores = compute_new_trailing_ignores(nil, @root)
      @parsing_queue << Directive(IdentT, NodeT).new(
        started_at: 0,
        group: @root,
        lr: false,
        current_ignores: initial_ignores,
        current_trailing_ignores: initial_trailing_ignores
      )

      # parse
      result_node = do_parse

      if result_node.nil?
        raise Error::BadInput.new("Parsing failed to match anything.")
      end

      # verify that every token was consumed
      position = @parsing_position
      if position < @parsing_tokens.size
        Log.debug { [
          "Got #{result_node.pretty_inspect}, but only matched ",
          "#{position}/#{@parsing_tokens.size} tokens.",
        ].join }
        raise Error::UnexpectedCharacter.new(
          @parsing_tokens[position].value[0],
          @parsing_tokens[position].position)
      end

      # done parsing
      result_node
    end

    private def generate_log_padding(offset : Int32 = 0)
      step = @parsing_queue.size + offset
      current_token = @parsing_tokens[@parsing_position]? || MatchedToken(Symbol).new(
        name: :"<EOL>",
        value: "",
        position: Position.new(@parsing_tokens[-1].position.row, @parsing_tokens[-1].position.col + 1)
      )

      [
        "#{step.to_s.rjust(2)}│",
        " #{@parsing_position.to_s.rjust(@parsing_tokens.size.to_s.size)}│",
        " #{current_token.position.row.to_s.rjust(2)},#{current_token.position.col.to_s.ljust(2)}│",
        " #{current_token.name.to_s.ljust(@longest_token_name_size)}",
        ("│" * Math.max(step - 1, 0)),
      ].join
    end

    private def do_parse : NodeT?
      loop do
        directive = @parsing_queue[-1]

        # parse one step
        if Util.upcase?(directive.target_ident)
          parse_token(directive)
        else
          parse_group(directive)
        end

        # run post parse actions and check if we got a result
        result = post_parse
        return result unless result.nil?
      end
    end

    private def post_parse : NodeT?
      loop do
        directive = @parsing_queue[-1]

        case directive.state
        in Directive::State::Waiting
          consume_trailing(directive.current_ignores)
          break
        in Directive::State::Matched
          result = post_parse_matched(directive)
          return result if result.is_a?(NodeT)
          return nil unless result  # continue loop if result is false
        in Directive::State::Failed
          result = post_parse_failed(directive)
          return nil unless result  # continue loop if result is false
        end
      end
      return nil
    end

    private def handle_parent_directive(directive, parent_directive) : NodeT | Bool
      return directive.context.result if parent_directive.nil? # final result

      if parent_directive.rule.pattern.size > 1 || parent_directive.lr?
        parent_directive.context.add(
          directive.group.name,
          directive.context
        )
      else
        parent_directive.context.merge(directive.context)
      end

      if parent_directive.end_of_pattern?
        parent_directive.state = Directive::State::Matched
      else
        parent_directive.next_target
        return false # continue the loop
      end
      true # continue processing the current directive
    end

    private def post_parse_matched(
      directive : Directive(IdentT, NodeT)
    ) : NodeT | Bool
      consume_trailing(directive.current_trailing_ignores)
      padding = generate_log_padding(-1)

      puts [
        "#{padding}└#{"\033[92;48;5;83;30m"}matched#{"\033[m"} ",
        directive.lr? ? "lr " : "",
        ":#{directive.context.name}",
      ].join

      if directive.lr?
        if directive.have_tried_lr?
          # remove as we're done with this directive
          @parsing_queue.pop
  
          # get parent directive
          parent_directive = @parsing_queue[-1]
          raise Error::Severe.new("No parent directive for lr") if parent_directive.nil?
  
          # merge parent context into self context
          self_context = directive.context
          parent_context = parent_directive.context

          pp parent_context  # stmts
          pp self_context    # stmt

          # wrap
          parent_context.flatten
          parent_context.subcontext_self

          # wrap fix for single pattern
          if directive.pattern.size == 1
            self_context.subcontext_self(as_key: directive.pattern[0])
          end

          parent_context.merge(self_context, clone: false)
          #self_context.merge(parent_context, clone: false)
          #parent_context = self_context

          puts "---1"
          pp parent_context
  
          # execute block on context
          directive.rule.block.try &.call(parent_context)

          puts "---2"
          pp parent_context
        else
          # set flag
          directive.set_have_tried_lr_flag

          # create lr directive
          @parsing_queue << Directive(IdentT, NodeT).new(
            started_at: @parsing_position,
            group: directive.group,
            lr: true,
            current_ignores: directive.current_ignores,
            current_trailing_ignores: directive.current_trailing_ignores
          )

          return false  # stop loop
        end
      elsif directive.have_tried_lr?
        @parsing_queue.pop
        return handle_parent_directive(directive, @parsing_queue[-1]?)
      else
        # execute block on context
        directive.rule.block.try &.call(directive.context)

        # store in cache
        @cache.store(
          ident: directive.group.name,
          context: directive.context,
          start_position: directive.started_at,
          parsing_position: @parsing_position
        )

        # check if we can try lr
        if directive.can_try_lr?
          puts "#{padding}┌trying lr :#{directive.group.name}"

          # set flag
          directive.set_have_tried_lr_flag

          # create lr directive
          @parsing_queue << Directive(IdentT, NodeT).new(
            started_at: @parsing_position,
            group: directive.group,
            lr: true,
            current_ignores: directive.current_ignores,
            current_trailing_ignores: directive.current_trailing_ignores
          )

          return false  # stop loop
        else
          # remove as we're done with this directive
          @parsing_queue.pop
          return handle_parent_directive(directive, @parsing_queue[-1]?)
        end
      end
      return true  # continue loop
    end

    private def post_parse_failed(
      directive : Directive(IdentT, NodeT)
    ) : Bool
      padding = generate_log_padding(-1)

      # traverse back up the queue
      puts [
        "#{padding}└failed ",
        directive.lr? ? "lr " : "",
        ":#{directive.target_ident}@:#{directive.group.name}",
      ].join

      # check if we can try a different rule
      if directive.can_advance_rule?
        @parsing_position = directive.started_at
        directive.next_rule
        return false  # stop loop
      else
        # removed failed directive from queue
        @parsing_queue.pop

        # check parent directive
        parent_directive = @parsing_queue[-1]?
        if parent_directive.nil?
          puts "#{padding}└backtracked until no more directives"
          return false  # stop loop
        else
          puts [
            "#{padding}└backtracked ",
            directive.lr? ? "from lr " : "",
            "to :#{parent_directive.group.name}",
          ].join
          @parsing_position = directive.started_at
          if (parent_directive.have_tried_lr? && 
              parent_directive.state == Directive::State::Matched)
            return true  # continue loop
          elsif parent_directive.can_advance_rule?
            parent_directive.next_rule
            return false  # stop loop
          else
            parent_directive.state = Directive::State::Failed
          end
        end
      end
      return true  # continue loop
    end

    private def parse_token(directive : Directive(IdentT, NodeT)) : Nil
      padding = generate_log_padding
      target_ident = directive.target_ident
      token = @tokens[target_ident]
      matched_token = expect_token(token, directive.current_ignores)

      unless matched_token.nil?
        puts "#{padding} matched :#{target_ident}"
        directive.add_to_context(target_ident, matched_token)
        if directive.end_of_pattern?
          directive.state = Directive::State::Matched
        else
          directive.next_target
        end
      else
        puts "#{padding} failed :#{target_ident}"
        directive.state = Directive::State::Failed
      end
    end

    private def parse_group(directive : Directive(IdentT, NodeT)) : Nil
      padding = generate_log_padding
      target_ident = directive.target_ident
      cached_context = expect_cache(target_ident)

      if cached_context.nil?
        puts "#{padding}┌trying :#{target_ident}"

        # advance this directive
        # directive.next_target(error: false)

        # insert new directive
        new_ignores = compute_new_ignores(
          directive.current_ignores,
          @groups[target_ident]
        )
        new_trailing_ignores = compute_new_trailing_ignores(
          directive.current_trailing_ignores,
          @groups[target_ident]
        )
        @parsing_queue << Directive(IdentT, NodeT).new(
          started_at: @parsing_position,
          group: @groups[target_ident],
          lr: false,
          current_ignores: new_ignores,
          current_trailing_ignores: new_trailing_ignores
        )
      else
        print_cache_details = false # FIXME: debug flag
        puts [
          "#{padding}└#{"\033[92;48;5;83;30m"}matched#{"\033[m"} :#{target_ident}",
          " #{"\033[92;48;5;83;30m"}from cache#{"\033[m"}",
          (print_cache_details ? ": #{cached_context.pretty_inspect}" : ""),
        ].join

        directive.add_to_context(target_ident, cached_context)

        if directive.end_of_pattern?
          directive.state = Directive::State::Matched
        else
          directive.next_target
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
          return nil # nothing matched
        end
      end
      return token # can be nil, a name-matched token, or an adapted token
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

      # Apply inherited ignores
      unless (inherited_ignores = group.inherited_ignores).nil?
        new_ignores.concat(inherited_ignores)
      end

      # Remove inherited noignores
      unless (inherited_noignores = group.inherited_noignores).nil?
        new_ignores.reject! { |ig| inherited_noignores.includes?(ig) }
      end

      # Apply local ignores (overriding inherited ones)
      unless (group_ignores = group.ignores).nil?
        new_ignores.concat(group_ignores)
      end

      # Remove local noignores (overriding inherited ones)
      unless (group_noignores = group.noignores).nil?
        new_ignores.reject! { |ig| group_noignores.includes?(ig) }
      end

      new_ignores.uniq!
      new_ignores
    end

    private def compute_new_trailing_ignores(
      current_trailing_ignores : Array(IdentT)?,
      group : Group(IdentT, NodeT)
    ) : Array(IdentT)
      new_trailing_ignores = current_trailing_ignores.nil? ? [] of IdentT : current_trailing_ignores.dup

      # Apply inherited trailing ignores
      unless (inherited_trailing_ignores = group.inherited_trailing_ignores).nil?
        new_trailing_ignores.concat(inherited_trailing_ignores)
      end

      # Apply local trailing ignores (overriding inherited ones)
      unless (group_trailing_ignores = group.trailing_ignores).nil?
        new_trailing_ignores.concat(group_trailing_ignores)
      end

      new_trailing_ignores.uniq!
      new_trailing_ignores
    end
  end
end
