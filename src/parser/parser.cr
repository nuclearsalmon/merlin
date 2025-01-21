class Merlin::Parser(IdentT, NodeT)
  include Tokenizer(IdentT)
  include ParserValidator(IdentT, NodeT)
  include ParserIgnores(IdentT, NodeT)
  include ParserLogic(IdentT, NodeT)

  # parser configuration
  # ---

  getter root : Group(IdentT, NodeT)
  getter groups : Hash(IdentT, Group(IdentT, NodeT))
  getter tokens : Hash(IdentT, Token(IdentT))
  property reference_recursion_limit : Int32
  property! debugger : Debugger(IdentT, NodeT)

  # parsing state
  # ---

  getter parsing_position : Int32 = 0
  getter parsing_tokens = Array(MatchedToken(IdentT)).new
  getter parsing_queue = Array(Directive(IdentT, NodeT)).new
  getter cache = Cache(IdentT, NodeT).new

  def initialize(
    @root : Group(IdentT, NodeT),
    @groups = Hash(IdentT, Group(IdentT, NodeT)).new,
    @tokens = Hash(IdentT, Token(IdentT)).new,
    @reference_recursion_limit : Int32 = 1024
  )
    @debugger = Debugger(IdentT, NodeT).new(self)
    
    validate_references_existance
    detect_and_fix_left_recursive_rules
    detect_unused_tokens
    detect_unused_groups
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
end
