module Merlin
  private class Directive(IdentT, NodeT)
    getter started_at       : Int32
    getter group            : Group(IdentT, NodeT)
    getter? lr              : Bool
    property? have_tried_lr : Bool = false
    property store_at       : Int32
    @rule_i                 : Int32 = 0
    @pattern_i              : Int32 = 0
    property? context       : Context(IdentT, NodeT)? = nil
    getter? done            : Bool = false

    delegate name, to: @group

    def initialize(
      @started_at : Int32,
      @group : Group(IdentT, NodeT),
      @lr : Bool
    )
      @store_at = @started_at
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

    def can_switch_to_lr? : Bool
      !(@lr || @group.lr_rules.empty?)
    end

    private def mark_done : Nil
      if @done
        raise Error::Severe.new("Cannot advance further, end is already reached.")
      else
        @done = true
      end
    end

    def next_rule(error : Bool = true) : Nil
      # see if inc possible
      if @rule_i + 1 >= rules.size
        if error
          mark_done
        else
          @done = true
        end
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
      "\n @have_tried_lr=#{@have_tried_lr}" +
      "\n @rule_i=#{@rule_i}" +
      "\n @pattern_i=#{@pattern_i}" +
      "\n @started_at=#{@started_at}" +
      "\n @done=#{@done}" +
      ">"
    end
  end
end
