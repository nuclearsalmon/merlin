module Merlin
  private class Directive(IdentT, NodeT)
    getter started_at : Int32
    getter group      : Group(IdentT, NodeT)
    getter lr         : Bool
    getter rule_i     : Int32 = 0
    getter pattern_i  : Int32 = 0
    getter? context   : Context(IdentT, NodeT)? = nil
    getter? done      : Bool = false

    def context : Context(IdentT, NodeT)
      @context ||= Context(IdentT, NodeT).new(group.name)
    end

    def name : IdentT?
      @group.name
    end

    def initialize(
      @started_at : Int32,
      @group : Group(IdentT, NodeT)
    )
      @lr = !(@group.lr_rules.empty?)
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

    def advance : Nil
      rules = rules()
      rule = rule()

      if @pattern_i + 1 >= rule.pattern.size
        # try inc rule
        if @rule_i + 1 >= rules.size
          # try non-lr
          if @lr && !(@group.rules.empty?)
            # non-lr
            @lr = false
            @rule_i = 0
            @pattern_i = 0
          elsif @done
            raise Error::Severe.new("Cannot advance further, end previously reached.")
          else
            @done = true
          end
        else
          # inc rule
          @rule_i += 1
          @pattern_i = 0
        end
      else
        # inc step
        @pattern_i += 1
      end
    end
  end
end
