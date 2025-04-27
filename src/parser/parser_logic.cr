module Merlin::ParserLogic(IdentT, NodeT)
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

  def parse(@parsing_tokens : Array(MatchedToken(IdentT))) : NodeT
    initialize_for_parsing
    result_node = do_parse

    # verify that we got a result
    raise Error::BadInput.new(
      "Parsing failed to match anything."
    ) if result_node.nil?
    
    # verify that every token was consumed
    if @parsing_position < @parsing_tokens.size
      self.debugger.log_line([
        "Got #{result_node.pretty_inspect}, but only matched ",
        "#{@parsing_position}/#{@parsing_tokens.size} tokens.",
      ].join)
      raise Error::UnexpectedCharacter.new(
        @parsing_tokens[@parsing_position].value[0],
        @parsing_tokens[@parsing_position].position)
    end

    # done parsing
    result_node
  end

  private def do_parse : NodeT?
    loop do
      directive = @parsing_queue[-1]?
      break if directive.nil?

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

        if next_token.nil?
          directive.state = Directive::State::Failed
          result = post_parse_failed(directive)
          break unless result # continue loop if result is false
        else
          break
        end
      in Directive::State::Matched
        result = post_parse_matched(directive)
        return result if result.is_a?(NodeT)
        break unless result # continue loop if result is false
      in Directive::State::Failed
        result = post_parse_failed(directive)
        break unless result # continue loop if result is false
      end
    end
    return nil
  end

  private def handle_parent_directive(directive, parent_directive) : NodeT | Bool
    return directive.context.result if parent_directive.nil?  # final result

    # decide whether to add or merge
    if parent_directive.rule.pattern.size > 1 || parent_directive.have_tried_lr?
      parent_directive.context.add(directive.group.name, directive.context)
    else
      parent_directive.context.merge(directive.context)
    end

    if parent_directive.end_of_pattern?
      parent_directive.state = Directive::State::Matched
      true
    else
      parent_directive.next_target
      false
    end
  end

  private def store_in_cache(directive : Directive(IdentT, NodeT)) : Nil
    @cache.store(
      ident: directive.group.name,
      context: directive.context,
      start_position: directive.started_at,
      parsing_position: @parsing_position
    )
  end

  private def create_lr_directive(directive : Directive(IdentT, NodeT)) : Nil
    @parsing_queue << Directive(IdentT, NodeT).new(
      started_at: @parsing_position,
      group: directive.group,
      lr: true,
      current_ignores: directive.current_ignores,
      current_trailing_ignores: directive.current_trailing_ignores
    )
  end

  private def post_parse_matched(
    directive : Directive(IdentT, NodeT)
  ) : NodeT | Bool
    consume_trailing_ignores(directive.current_trailing_ignores)
    self.debugger.log_matched(directive.context.name, lr: directive.lr?)

    if directive.lr?
      # remove as we're done with this directive
      @parsing_queue.pop

      # get parent directive
      parent_directive = @parsing_queue[-1]?
      raise Error::Severe.new("Missing parent directive for lr") if parent_directive.nil?

      # Prepare parent context
      parent_context = parent_directive.context
      parent_context.flatten
      parent_context.subcontext_self

      # Handle single pattern case
      if directive.pattern.size == 1
        directive.context.subcontext_self(as_key: directive.pattern[0])
      end

      # Merge contexts and execute block
      parent_context.merge(directive.context, clone: false, overwrite_subcontexts: false)

      directive.rule.block.try &.call(parent_context)

      # cache the updated parent context
      store_in_cache(parent_directive)

      create_lr_directive(parent_directive) unless next_token().nil?
      false
    elsif directive.have_tried_lr?
      @parsing_queue.pop
      handle_parent_directive(directive, @parsing_queue[-1]?)
    else
      # Execute block and store in cache
      directive.rule.block.try &.call(directive.context)
      store_in_cache(directive)

      # Try LR if possible
      if !next_token().nil? && directive.can_try_lr?
        self.debugger.log_trying(directive.group.name, lr: true)
        directive.set_have_tried_lr_flag  # set flag

        create_lr_directive(directive)
        false
      else
        # remove as we're done with this directive
        @parsing_queue.pop
        handle_parent_directive(directive, @parsing_queue[-1]?)
      end
    end
  end

  private def post_parse_failed(
    directive : Directive(IdentT, NodeT)
  ) : Bool
    self.debugger.log_failed(
      directive.target_ident, 
      directive.group.name, 
      lr: directive.lr?
    )

    @parsing_position = directive.started_at

    # traverse back up the queue, check if we can try a different rule
    if directive.can_advance_rule?
      directive.next_rule
      return false
    else
      # removed failed directive from queue
      @parsing_queue.pop

      # check parent directive
      parent_directive = @parsing_queue[-1]?
      if parent_directive.nil?
        self.debugger.log_halted_backtracking
        return false
      else
        self.debugger.log_backtracked(
          to_key: parent_directive.group.name,
          from_lr: directive.lr?
        )

        if (parent_directive.have_tried_lr? &&
           parent_directive.state == Directive::State::Matched)
          return true
        elsif parent_directive.can_advance_rule?
          parent_directive.next_rule
          @parsing_position = parent_directive.started_at
          return false
        else
          parent_directive.state = Directive::State::Failed
          return true
        end
      end
    end
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

      if next_token.nil?
        raise Exception.new("No more tokens to parse")
      end

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
      ) unless next_token().nil?
      # FIXME: the "unless" clause here is a performance hack to 
      # avoid creating a new directive if there are no more tokens.
      # This does seem to work but could have unforeseen side effects.
      # Ideally this should be handled before attempting to parse a group.
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
