module Merlin
  class GroupBuilder(IdentT, NodeT)
    @name : IdentT
    @rules = Array(Rule(IdentT, NodeT)).new
    @lr_rules = Array(Rule(IdentT, NodeT)).new
    @ignores : Array(IdentT)? = nil
    @noignores : Array(IdentT)? = nil
    @trailingignores : Array(IdentT)? = nil

    def self.new(name : IdentT, &)
      with Group.new(name) yield
    end

    def initialize(@name : IdentT)
    end

    def build : Group(IdentT, NodeT)
      Group(IdentT, NodeT).new(
        @name,
        @rules,
        @lr_rules,
        @ignores,
        @noignores,
        @trailing_ignores)
    end

    private def rule(rule : Rule(IdentT, NodeT)) : Nil
      if rule.pattern[0] == @name
        rule.pattern.shift
        @lr_rules << rule
      else
        @rules << rule
      end
    end

    private def rule(pattern : IdentT) : Nil
      rule(Rule(IdentT, NodeT).new([pattern], nil))
    end

    private def rule(*pattern : IdentT) : Nil
      rule(Rule(IdentT, NodeT).new(pattern.to_a, nil))
    end

    private def rule(
        pattern : IdentT,
        &block : Proc(Context(IdentT, NodeT), Nil)) : Nil
      rule(Rule(IdentT, NodeT).new([pattern], block))
    end

    private def rule(
        *pattern : IdentT,
        &block : Proc(Context(IdentT, NodeT), Nil)) : Nil
      rule(Rule(IdentT, NodeT).new(pattern.to_a, block))
    end

    private def rule(
        pattern : Array(IdentT)) : Nil
      rule(Rule(IdentT, NodeT).new(pattern, nil))
    end

    private def rule(
        pattern : Array(IdentT),
        &block : Proc(Context(IdentT, NodeT), Nil)) : Nil
      rule(Rule(IdentT, NodeT).new(pattern, block))
    end

    private def noignore() : Nil
      @noignores ||= Array(IdentT).new
    end

    private def noignore(pattern : IdentT) : Nil
      unless Util.upcase?(pattern.to_s)
        raise Error::SyntaxFault.new("Only tokens can be ignored.")
      end
      (@noignores ||= Array(IdentT).new) << pattern
    end

    private def ignore(pattern : IdentT) : Nil
      unless Util.upcase?(pattern.to_s)
        raise Error::SyntaxFault.new("Only tokens can be ignored.")
      end
      (@ignores ||= Array(IdentT).new) << pattern
    end

    private def ignore_trailing(pattern : IdentT) : Nil
      unless Util.upcase?(pattern.to_s)
        raise Error::SyntaxFault.new("Only tokens can be ignored.")
      end
      (@trailing_ignores ||= Array(IdentT).new) << pattern
    end
  end
end
