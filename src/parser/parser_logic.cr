module Merlin::ParserLogic(IdentT, NodeT)
  def parse(@parsing_tokens : Array(MatchedToken(IdentT))) : NodeT
    initialize_for_parsing

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

  private def initialize_for_parsing : Nil
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
      break result unless result.nil?
    end
  end

  private def post_parse : NodeT?
    loop do
      directive = @parsing_queue[-1]

      case directive.state
      in Directive::State::Waiting
        consume_trailing_ignores(directive.current_ignores)
        break
      in Directive::State::Matched
        result = post_parse_matched(directive)
        return result if result.is_a?(NodeT)
        return nil unless result # continue loop if result is false
      in Directive::State::Failed
        result = post_parse_failed(directive)
        return nil unless result # continue loop if result is false
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
      return true  # continue processing the current directive
    else
      parent_directive.next_target
      return false  # continue the loop
    end
  end

  private def post_parse_matched(
    directive : Directive(IdentT, NodeT)
  ) : NodeT | Bool
    consume_trailing_ignores(directive.current_trailing_ignores)

    self.debugger.log_matched(
      directive.context.name, 
      lr: directive.lr?
    )

    if directive.lr?
      # remove as we're done with this directive
      @parsing_queue.pop

      # get parent directive
      parent_directive = @parsing_queue[-1]
      raise Error::Severe.new("Missing parent directive for lr") if parent_directive.nil?

      # prepare to inject/merge self context into parent context
      self_context = directive.context
      parent_context = parent_directive.context

      # wrap
      parent_context.flatten
      parent_context.subcontext_self

      # wrap fix for single pattern
      if directive.pattern.size == 1
        self_context.subcontext_self(as_key: directive.pattern[0])
      end

      # inject/merge self context into parent context
      parent_context.merge(self_context, clone: false)

      # execute this directive's block on the final (parent)context
      directive.rule.block.try &.call(parent_context)
      # the parent is now complete

      # cache the updated parent context
      @cache.store(
        ident: parent_directive.group.name,
        context: parent_context,
        start_position: parent_directive.started_at,
        parsing_position: @parsing_position
      )

      return true  # we've reached the end of the directive
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
      if (@parsing_position != @parsing_tokens.size) && directive.can_try_lr?
        self.debugger.log_trying(
          directive.group.name, 
          lr: true
        )

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

        return false # stop loop
      else
        # remove as we're done with this directive
        @parsing_queue.pop
        return handle_parent_directive(directive, @parsing_queue[-1]?)
      end
    end
    return true # continue loop
  end

  private def post_parse_failed(
    directive : Directive(IdentT, NodeT)
  ) : Bool
    self.debugger.log_failed(
      directive.target_ident, 
      directive.group.name, 
      lr: directive.lr?
    )

    # traverse back up the queue, check if we can try a different rule
    if directive.can_advance_rule?
      @parsing_position = directive.started_at
      directive.next_rule
      return false # stop loop
    else
      # removed failed directive from queue
      @parsing_queue.pop

      # check parent directive
      parent_directive = @parsing_queue[-1]?
      if parent_directive.nil?
        self.debugger.log_halted_backtracking
        return false # stop loop
      else
        self.debugger.log_backtracked(
          to_key: parent_directive.group.name,
          from_lr: directive.lr?
        )


        @parsing_position = directive.started_at
        if (parent_directive.have_tried_lr? &&
           parent_directive.state == Directive::State::Matched)
          return true # continue loop
        elsif parent_directive.can_advance_rule?
          parent_directive.next_rule
          return false # stop loop
        else
          parent_directive.state = Directive::State::Failed
        end
      end
    end
    return true # continue loop
  end

  private def parse_token(directive : Directive(IdentT, NodeT)) : Nil
    target_ident = directive.target_ident
    token = @tokens[target_ident]
    matched_token = expect_token(token, directive.current_ignores)

    unless matched_token.nil?
      self.debugger.log_matched(target_ident)

      directive.add_to_context(target_ident, matched_token)
      if directive.end_of_pattern?
        directive.state = Directive::State::Matched
      else
        directive.next_target
      end
    else
      directive.state = Directive::State::Failed
    end
  end

  private def parse_group(directive : Directive(IdentT, NodeT)) : Nil
    target_ident = directive.target_ident
    cached_context = expect_cache(target_ident)

    if cached_context.nil?
      self.debugger.log_trying(target_ident)

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
      self.debugger.log_matched(
        target_ident,
        from_cache: true
      )

      directive.add_to_context(target_ident, cached_context)

      if directive.end_of_pattern?
        directive.state = Directive::State::Matched
      else
        directive.next_target
      end
    end
  end
end
