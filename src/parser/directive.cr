module Merlin
  private class Directive(IdentT, NodeT)
    enum State
      Waiting
      Matched
      Failed
    end

    getter group                    : Group(IdentT, NodeT)
    getter started_at               : Int32
    @rule_i                         : Int32 = 0
    @pattern_i                      : Int32 = 0
    getter? lr                      : Bool
    getter? have_tried_lr           : Bool = false
    property? context               : Context(IdentT, NodeT)? = nil
    property state                  : State = State::Waiting
    getter current_ignores          : Array(IdentT)
    getter current_trailing_ignores : Array(IdentT)

    delegate name, to: @group

    private def initialize(
      @started_at               : Int32,
      @group                    : Group(IdentT, NodeT),
      @lr                       : Bool,
      @rule_i                   : Int32,
      @pattern_i                : Int32,
      @context                  : Context(IdentT, NodeT)?,
      @state                    : State,
      @current_ignores          : Array(IdentT),
      @current_trailing_ignores : Array(IdentT)
    )
    end

    def initialize(
      @started_at               : Int32,
      @group                    : Group(IdentT, NodeT),
      @lr                       : Bool,
      @current_ignores          : Array(IdentT),
      @current_trailing_ignores : Array(IdentT)
    )
    end

    def clone : Directive(IdentT, NodeT)
      Directive.new(
        @started_at,
        @group,
        @lr,
        @rule_i,
        @pattern_i,
        @context.try(&.clone),
        @state,
        @current_ignores.dup,
        @current_trailing_ignores.dup
      )
    end

    def context : Context(IdentT, NodeT)
      @context ||= Context(IdentT, NodeT).new(group.name)
    end

    def reset_context : Nil
      @context.try(&.reset(name))
    end

    def add_to_context(
      name : IdentT,
      token : MatchedToken(IdentT)
    ) : Nil
      if rule.pattern.size > 1
        context.add(name, token)
      else
        context.add(token)
      end
    end

    def add_to_context(
      name : IdentT,
      new_context : Context(IdentT, NodeT)
    ) : Nil
      if rule.pattern.size > 1
        context.add(name, new_context)
      else
        context.merge(new_context)
      end
    end

    def rules : Array(Rule(IdentT, NodeT))
      @lr ? @group.lr_rules : @group.rules
    end

    def rule : Rule(IdentT, NodeT)
      rules[@rule_i]
    end

    def pattern : Array(IdentT)
      rule.pattern
    end

    def target_ident : IdentT
      pattern[@pattern_i]
    end

    def can_advance_pattern? : Bool
      @pattern_i + 1 < pattern.size
    end

    def can_advance_rule? : Bool
      @rule_i + 1 < rules.size
    end

    def can_try_lr? : Bool
      !@have_tried_lr && !@lr && !@group.lr_rules.empty?
    end

    def end_of_pattern? : Bool
      @pattern_i + 1 >= rule.pattern.size
    end

    def end_of_rule? : Bool
      @rule_i + 1 >= rules.size
    end

    def set_have_tried_lr_flag : Nil
      raise Error::Severe.new("Already tried lr") if @have_tried_lr
      @have_tried_lr = true
    end

    def next_rule(error : Bool = true) : Nil
      # see if inc possible
      if @rule_i + 1 >= rules.size
        raise Error::Severe.new(
          "Cannot advance further, reached end of" +
          "#{@lr ? "lr" : ""} rules.") if error
      else
        reset_context   # reset context
        @rule_i += 1    # inc rule
        @pattern_i = 0  # reset pattern
      end
    end

    def next_target(error : Bool = true) : Nil
      if @pattern_i + 1 >= rule.pattern.size
        raise Error::Severe.new(
          "Cannot advance further, reached end of pattern for" +
          "#{@lr ? "lr" : ""} rule #{rule.pattern}.") if error
      else
        @pattern_i += 1
      end
    end

    def to_s : String
      pretty_context_s = @context
        .try(&.pretty_inspect
        .lines[1..]
        .map{ |line| "\n #{line}" })

      "<Directive \"#{name}\":" +
      "\n @started_at=#{@started_at}" +
      "\n @rule_i=#{@rule_i}" +
      "\n @pattern_i=#{@pattern_i}" +
      "\n @lr=#{@lr}" +
      "\n @group=#{@group.name}" +
      "\n @context=#{pretty_context_s}" +
      ">"
    end
  end
end
