module Merlin
  private class Directive(IdentT, NodeT)
    getter started_at : Int32
    getter group      : Group(IdentT, NodeT)
    getter lr         : Bool = false
    getter rule_i     : Int32 = 0
    getter pattern_i  : Int32 = 0
    getter? context   : Context(IdentT, NodeT)? = nil
    getter? done      : Bool = false

    def initialize(
      @started_at : Int32,
      @group : Group(IdentT, NodeT))
    end

    def context : Context(IdentT, NodeT)
      @context ||= Context(IdentT, NodeT).new(group.name)
    end

    def reset_context : Nil
      @context.try(&.reset(name))
    end

    def add(
      name : IdentT,
      token : MatchedToken(IdentT)
    ) : Nil
      if rule.pattern.size > 1
        context.add(name, token)
      else
        context.add(token)
      end
    end

    def add(
      name : IdentT,
      new_context : Context(IdentT, NodeT)
    ) : Nil
      if rule.pattern.size > 1
        context.unsafe_add(name, new_context)
      else
        context.unsafe_merge(new_context)
      end
    end

    def name : IdentT?
      @group.name
    end

    def rules : Array(Rule(IdentT, NodeT))
      @lr ? @group.lr_rules : @group.rules
    end

    def rule : Rule(IdentT, NodeT)
      rules()[@rule_i]
    end

    def pattern : Array(IdentT)
      rule.pattern
    end

    def target_ident : IdentT
      rule().pattern[@pattern_i]
    end

    private def mark_done : Nil
      if @done
        raise Error::Severe.new("Cannot advance further, end previously reached.")
      else
        @done = true
      end
    end

    private def switch_to_lr_rules(error : Bool) : Nil
      if !@lr && !(@group.lr_rules.empty?)
        # non-lr
        @lr = true
        @done = false
        @rule_i = 0
        @pattern_i = 0
      elsif error
        mark_done
      else
        @done = true
      end
    end

    def next_rule(error : Bool = true) : Nil
      # see if inc possible
      if @rule_i + 1 >= rules.size
        switch_to_lr_rules(error: error)
      else
        # inc rule
        @done = false
        @rule_i += 1
        @pattern_i = 0
      end
    end

    def next_target : Nil
      if @pattern_i + 1 >= rule.pattern.size
        mark_done
      else
        @done = false
        @pattern_i += 1
      end
    end

    def to_s : String
      pretty_context_s = @context
        .pretty_inspect
        .lines[1..]
        .map{ |line| "\n #{line}" }
        .join
      "<Directive \"#{name}\":" +
      "\n @context=#{pretty_context_s}" +
      "\n @lr=#{@lr}" +
      "\n @rule_i=#{@rule_i}" +
      "\n @pattern_i=#{@pattern_i}" +
      "\n @started_at=#{@started_at}" +
      "\n @done=#{@done}" +
      ">"
    end
  end
end
