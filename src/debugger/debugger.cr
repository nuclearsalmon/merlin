class Merlin::Debugger(IdentT, NodeT)
  ANSI_RESET = "\x1b[m"
  ANSI_HIGHLIGHT = "\x1b[38;2;253;134;42;3m"

  # step fields
  property step_field_stack_depth    = false
  property step_field_token_number   = false
  property step_field_token_position = false
  property step_field_token_name     = true
  property step_field_trying_group   = true
  property step_field_failed         = true
  property step_field_matched        = true
  property step_field_backtracked    = false

  # ansi highlights
  property highlight_trying_group   = false
  property highlight_failed         = false
  property highlight_matched        = true
  property highlight_backtracked    = false

  # filters
  property filter_stack_depth    = -1
  property filter_token_number   = -1
  property filter_token_position = -1
  property filter_token_name     = ""
  property filter_parent_group   = ""

  # actions
  property show_steps        = false
  property pad_steps         = true
  property fancy_padding     = true
  property show_tokenization = false
  property show_ast          = false

  SEPARATOR = "│"

  @max_token_name_len = 0
  @max_token_number_len = 0
  @max_token_position_len = 0

  @parser : Parser(IdentT, NodeT)

  def initialize(@parser : Parser(IdentT, NodeT))
  end

  def initialize_inspector
    @max_token_name_len = [
      @parser.tokens.values.map { |token| token.name.size }.max,
      @parser.groups.values.map { |group| group.name.size }.max,
      @parser.root.name.size
    ].compact.max

    @max_token_number_len = @parser.parsing_tokens.size.to_s.size
    max_token_position_row_len = @parser.parsing_tokens.map { |token| 
      token.position.row.to_s.size
    }.max

    max_token_position_col_len = @parser.parsing_tokens.map { |token| 
      token.position.col.to_s.size
    }.max

    @max_token_position_len = max_token_position_row_len + max_token_position_col_len + 1
  end

  private def _log_line(
    step_str : String, 
    step_padding_prefix : String = SEPARATOR,
    step_offset : Int = -1
  ) : Nil
    return unless @show_steps 
    step = @parser.parsing_queue.size + step_offset
    current_token = @parser.parsing_tokens[@parser.parsing_position]? || MatchedToken(Symbol).new(
      name: :"<EOL>",
      value: "",
      position: Position.new(@parser.parsing_tokens[-1].position.row, @parser.parsing_tokens[-1].position.col + 1)
    )

    line = [
      @pad_steps ? [
        (@fancy_padding ? SEPARATOR : " ") * Math.max(step - 1, 0),
        step_padding_prefix
      ].join : "",
      step_str,
      @step_field_stack_depth ? "#{step.to_s.rjust(step.to_s.size)}" : "",
      @step_field_token_number ? (
        "#{SEPARATOR} #{@parser.parsing_position.to_s.rjust(
          @max_token_number_len*2+1)}/#{@max_token_number_len}"
      ) : "",
      @step_field_token_position ? (
        "#{SEPARATOR} #{
          "#{current_token.position.row},#{current_token.position.col}"
          .rjust(@max_token_position_len)
        }"
      ) : "",
      @step_field_token_name ? (
        "#{SEPARATOR} #{current_token.name.to_s.ljust(@max_token_name_len)}"
      ) : ""
    ].join

    puts line
  end

  def log_line(line : String) : Nil
    _log_line(step_str: line)
  end

  def log_trying(
    key : IdentT,
    lr : Bool = false
  ) : Nil
    highlight = @highlight_trying_group  # local copy state
    _log_line(
      [
        highlight ? ANSI_HIGHLIGHT : "",
        "trying",
        highlight ? ANSI_RESET : "",
        lr ? " lr" : "",
        " :#{key}"
      ].join,
      step_padding_prefix: "┌"
    ) if @step_field_trying_group
  end

  def log_failed(
    pattern_target_key : IdentT,
    group_key : IdentT,
    lr : Bool = false
  ) : Nil
    highlight = @highlight_failed  # local copy state
    _log_line(
      [
        highlight ? ANSI_HIGHLIGHT : "",
        "failed",
        highlight ? ANSI_RESET : "",
        lr ? " lr" : "",
        " :#{pattern_target_key}@:#{group_key}"
      ].join,
      step_offset: 0
    ) if @step_field_failed
  end

  def log_matched(
    key : IdentT,
    lr : Bool = false,
    from_cache : Bool = false
  ) : Nil
    highlight = @highlight_matched  # local copy state
    _log_line(
      [
        highlight ? ANSI_HIGHLIGHT : "",
        "matched",
        highlight ? ANSI_RESET : "",
        lr ? " lr" : "",
        " :#{key}",
        from_cache ? " from cache" : ""
      ].join,
      step_offset: 0
    ) if @step_field_matched
    # TODO: add ability to log/dump cache details
  end

  def log_backtracked(
    to_key : IdentT,
    from_lr : Bool,
  ) : Nil
    highlight = @highlight_backtracked  # local copy state
    _log_line(
      [
        highlight ? ANSI_HIGHLIGHT : "",
        "backtracked",
        from_lr ? " from lr" : "",
        highlight ? ANSI_RESET : "",
        " to :#{to_key}"
      ].join,
      step_offset: 0,
      step_padding_prefix: SEPARATOR
    ) if @step_field_backtracked
  end

  def log_halted_backtracking
    highlight = @highlight_backtracked  # local copy state
    _log_line(
      [
        highlight ? ANSI_HIGHLIGHT : "",
        "halted backtracking, there are no more directives",
        highlight ? ANSI_RESET : "",
      ].join,
      step_offset: 0,
      step_padding_prefix: "└"
    ) if @step_field_backtracked
  end
end

