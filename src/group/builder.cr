module Merlin
  private class GroupBuilder(IdentT, NodeT)
    getter name      : IdentT
    @lr_rules        = Array(Rule(IdentT, NodeT)).new
    @rules           = Array(Rule(IdentT, NodeT)).new
    @optional        = false
    @ignores         : Array(IdentT)? = nil
    @noignores       : Array(IdentT)? = nil
    @trailingignores : Array(IdentT)? = nil
    @inherited_ignores : Array(IdentT)? = nil
    @inherited_noignores : Array(IdentT)? = nil
    @inherited_trailing_ignores : Array(IdentT)? = nil

    def initialize(@name : IdentT)
    end

    def build : Group(IdentT, NodeT)
      Group(IdentT, NodeT).new(
        name: @name,
        lr_rules: @lr_rules,
        rules: @rules,
        optional: @optional,
        ignores: @ignores,
        noignores: @noignores,
        trailing_ignores: @trailing_ignores,
        inherited_ignores: @inherited_ignores,
        inherited_noignores: @inherited_noignores,
        inherited_trailing_ignores: @inherited_trailing_ignores
      )
    end

    #def self.build(name : IdentT?, &)
    #  group_builder = with self.new(name) yield
    #  group_builder.build
    #end

    private def rule(rule : Rule(IdentT, NodeT)) : Nil
      if rule.pattern.size == 0
        raise Error::SyntaxFault.new(
          "Rules must not have empty patterns.")
      end

      if !(@name.nil?) && (rule.pattern[0] == @name)
        if rule.pattern.size < 2
          raise Error::SyntaxFault.new(
            "Left-recursive rules must have at least two patterns")
        end

        rule.pattern.shift
        #@lr_rules.each{|r|
        #  if r.pattern == rule.pattern
        #    pp r
        #    pp rule
        #    pp self
        #    raise "err A"
        #  end
        #}
        @lr_rules << rule
      else
        #@lr_rules.each{|r|
        #  if r.pattern == rule.pattern
        #    pp r
        #    pp rule
        #    pp self
        #    raise "err B"
        #  end
        #}
        @rules << rule
      end
    end

    def rule(pattern : IdentT) : Nil
      rule(Rule(IdentT, NodeT).new([pattern], nil))
    end

    def rule(*pattern : IdentT) : Nil
      rule(Rule(IdentT, NodeT).new(pattern.to_a, nil))
    end

    def rule(
        pattern : IdentT,
        &block : Proc(Context(IdentT, NodeT), Nil)) : Nil
      rule(Rule(IdentT, NodeT).new([pattern], block))
    end

    def rule(
        *pattern : IdentT,
        &block : Proc(Context(IdentT, NodeT), Nil)) : Nil
      rule(Rule(IdentT, NodeT).new(pattern.to_a, block))
    end

    def rule(
        pattern : Array(IdentT)) : Nil
      rule(Rule(IdentT, NodeT).new(pattern, nil))
    end

    def rule(
        pattern : Array(IdentT),
        &block : Proc(Context(IdentT, NodeT), Nil)) : Nil
      rule(Rule(IdentT, NodeT).new(pattern, block))
    end

    def noignore() : Nil
      @noignores ||= Array(IdentT).new
    end

    private def check_token(pattern : IdentT) : Nil
      unless Util.upcase?(pattern.to_s)
        raise Error::SyntaxFault.new("Only tokens can be ignored.")
      end
    end

    def noignore(pattern : IdentT) : Nil
      check_token(pattern)
      (@noignores ||= Array(IdentT).new) << pattern
    end

    def ignore(pattern : IdentT) : Nil
      check_token(pattern)
      (@ignores ||= Array(IdentT).new) << pattern
    end

    def ignore_trailing(pattern : IdentT) : Nil
      check_token(pattern)
      (@trailing_ignores ||= Array(IdentT).new) << pattern
    end

    def optional : Nil
      @optional = true
    end

    def inherited_ignore(pattern : IdentT) : Nil
      check_token(pattern)
      (@inherited_ignores ||= Array(IdentT).new) << pattern
    end

    def inherited_noignore(pattern : IdentT) : Nil
      check_token(pattern)
      (@inherited_noignores ||= Array(IdentT).new) << pattern
    end

    def inherited_ignore_trailing(pattern : IdentT) : Nil
      check_token(pattern)
      (@inherited_trailing_ignores ||= Array(IdentT).new) << pattern
    end
  end
end
