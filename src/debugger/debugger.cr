class Merlin::Debugger(IdentT, NodeT)
  ANSI_RESET     = "\x1b[m"
  ANSI_HIGHLIGHT = "\x1b[38;2;253;134;42;3m"
  SEPARATOR      = "│"

  property enabled          = false
  property show_trying      = true
  property show_matched     = true
  property show_failed      = true
  property show_backtracked = false

  property max_depth      = -1
  property only_groups    = [] of String
  property exclude_groups = [] of String

  property padding            = true
  property fancy_padding      = true
  property show_current_token = true
  property highlight          = true

  @inspector_initialized = false
  @max_token_name_len = 0

  @parser : Parser(IdentT, NodeT)

  def initialize(@parser : Parser(IdentT, NodeT))
  end

  def initialize_inspector
    @max_token_name_len = [
      @parser.tokens.values.map { |t| t.name.to_s.size }.max,
      @parser.groups.values.map { |g| g.name.to_s.size }.max,
      @parser.root.name.to_s.size,
    ].compact.max
    @inspector_initialized = true
  end

  private def depth : Int32
    @parser.parsing_queue.size
  end

  private def should_log? : Bool
    return false unless @enabled
    @max_depth < 0 || depth <= @max_depth
  end

  private def should_log?(group_key : IdentT) : Bool
    return false unless should_log?
    name = group_key.to_s
    return false if !@only_groups.empty? && !@only_groups.includes?(name)
    return false if @exclude_groups.includes?(name)
    true
  end

  private def current_token_name : String
    token = @parser.parsing_tokens[@parser.parsing_position]?
    token ? token.name.to_s : "<EOL>"
  end

  private def emit(
    text : String,
    prefix : String = SEPARATOR,
    depth_offset : Int32 = -1
  ) : Nil
    initialize_inspector unless @inspector_initialized
    step = depth + depth_offset

    io = String::Builder.new
    if @padding
      pad_char = @fancy_padding ? SEPARATOR : " "
      Math.max(step - 1, 0).times { io << pad_char }
      io << prefix
    end
    io << text
    if @show_current_token
      io << SEPARATOR << " " << current_token_name
    end
    puts io.to_s
  end

  private def hl(text : String) : String
    @highlight ? "#{ANSI_HIGHLIGHT}#{text}#{ANSI_RESET}" : text
  end

  def log_line(line : String) : Nil
    return unless should_log?
    emit(text: line)
  end

  def log_trying(key : IdentT, lr : Bool = false) : Nil
    return unless @show_trying && should_log?(key)
    emit(
      text: "#{hl("trying")}#{lr ? " lr" : ""} :#{key}",
      prefix: "┌"
    )
  end

  def log_failed(
    pattern_target_key : IdentT,
    group_key : IdentT,
    lr : Bool = false
  ) : Nil
    return unless @show_failed && should_log?(group_key)
    emit(
      text: "#{hl("failed")}#{lr ? " lr" : ""} :#{pattern_target_key}@:#{group_key}",
      depth_offset: 0
    )
  end

  def log_matched(
    key : IdentT,
    lr : Bool = false,
    from_cache : Bool = false
  ) : Nil
    return unless @show_matched && should_log?(key)
    emit(
      text: "#{hl("matched")}#{lr ? " lr" : ""} :#{key}#{from_cache ? " from cache" : ""}",
      depth_offset: 0
    )
  end

  def log_backtracked(
    to_key : IdentT,
    from_lr : Bool,
  ) : Nil
    return unless @show_backtracked && should_log?(to_key)
    emit(
      text: "#{hl("backtracked")}#{from_lr ? " from lr" : ""} to :#{to_key}",
      depth_offset: 0,
      prefix: SEPARATOR
    )
  end

  def log_halted_backtracking
    return unless @show_backtracked && should_log?
    emit(
      text: hl("halted backtracking, there are no more directives"),
      depth_offset: 0,
      prefix: "└"
    )
  end
end
