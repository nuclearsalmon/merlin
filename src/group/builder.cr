module Merlin
  private class GroupBuilder(IdentT, NodeT)
    getter name      : IdentT
    @lr_rules        = Array(Rule(IdentT, NodeT)).new
    @rules           = Array(Rule(IdentT, NodeT)).new
    @optional        = false
    @ignores         : Array(IdentT)? = nil
    @noignores       : Array(IdentT)? = nil
    @trailingignores : Array(IdentT)? = nil

    def initialize(@name : IdentT)
    end

    private def compute_ignores(root_ignores : Array(IdentT)?) : Array(IdentT)?
      ignores = @ignores
      noignores = @noignores
      final_ignores = Array(IdentT).new

      if noignores.nil?
        final_ignores.concat(root_ignores) unless root_ignores.nil?
      elsif noignores.size > 0
        unless root_ignores.nil?
          root_ignores.each { |ig_sym|
            next if !(noignores.nil?) && noignores.includes?(ig_sym)
            final_ignores << ig_sym
          }
        end
      end
      final_ignores.concat(ignores) unless ignores.nil?

      return final_ignores.empty? ? nil : final_ignores
    end

    def build(with_root : Group(IdentT, NodeT)?) : Group(IdentT, NodeT)
      # compute ignores
      root_ignores = with_root.try(&.computed_ignores)
      computed_ignores = compute_ignores(root_ignores)

      # build
      Group(IdentT, NodeT).new(
        name:             @name,
        lr_rules:         @lr_rules,
        rules:            @rules,
        optional:         @optional,
        computed_ignores: computed_ignores,
        trailing_ignores: @trailing_ignores)
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

      if !((name = @name).nil?) && rule.pattern[0] == name
        if rule.pattern.size < 2
          raise Error::SyntaxFault.new(
            "Left-recursive rules must have at least two patterns")
        end

        rule.pattern.shift
        @lr_rules << rule
      else
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
      if @name.nil?
        raise SyntaxFault.new("A root group cannot use noignore.")
      end

      @noignores ||= Array(IdentT).new
    end

    def noignore(pattern : IdentT) : Nil
      if @name.nil?
        raise SyntaxFault.new("A root group cannot use noignore.")
      end

      unless Util.upcase?(pattern.to_s)
        raise Error::SyntaxFault.new("Only tokens can be ignored.")
      end
      (@noignores ||= Array(IdentT).new) << pattern
    end

    def ignore(pattern : IdentT) : Nil
      unless Util.upcase?(pattern.to_s)
        raise Error::SyntaxFault.new("Only tokens can be ignored.")
      end
      (@ignores ||= Array(IdentT).new) << pattern
    end

    def ignore_trailing(pattern : IdentT) : Nil
      unless Util.upcase?(pattern.to_s)
        raise Error::SyntaxFault.new("Only tokens can be ignored.")
      end
      (@trailing_ignores ||= Array(IdentT).new) << pattern
    end

    def optional : Nil
      @optional = true
    end
  end
end
