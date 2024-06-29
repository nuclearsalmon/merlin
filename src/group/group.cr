module Merlin
  private class Group(IdentT, NodeT)
    getter name
    getter rules, lr_rules
    getter ignores, noignores, trailing_ignores

    @name : IdentT
    @rules : Array(Rule(IdentT, NodeT))
    @lr_rules : Array(Rule(IdentT, NodeT))
    @ignores : Array(IdentT)?
    @noignores : Array(IdentT)?
    @trailing_ignores : Array(IdentT)?

    def initialize(
        @name : IdentT,
        @rules : Array(Rule(IdentT, NodeT)),
        @lr_rules : Array(Rule(IdentT, NodeT)),
        @ignores : Array(IdentT)? = nil,
        @noignores : Array(IdentT)? = nil,
        @trailing_ignores : Array(IdentT)? = nil)
    end

    private def try_rules(
        parser : Parser(IdentT, NodeT),
        context_for_lr : Context(IdentT, NodeT)?,
        computed_ignores : Array(IdentT)) : Context(IdentT, NodeT)?
      rules = (context_for_lr.nil? ? @rules : @lr_rules)
      rules.each do |rule|
        context = rule.try_patterns(@name, parser, computed_ignores)
        unless context.nil?
          block = rule.block
          unless block.nil?
            unless context_for_lr.nil?
              context_for_lr.merge(context)
              context = context_for_lr
            end

            Log.debug {
              "Executing block for rule " +
              "#{rule.pattern}@:#{@name} ..."
            }
            block.call(context)
          end

          # matched, so consume trailing ignores
          trailing_ignores = @trailing_ignores
          unless trailing_ignores.nil?
            loop do
              token = parser.next_token(trailing_ignores)
              break if token.nil?
            end
          end

          return context
        end
      end
      return nil
    end

    def parse(parser : Parser(IdentT, NodeT)) : Context(IdentT, NodeT)?
      #Log.debug { "... trying rules for :#{@name} ..." }

      # compute ignores
      computed_ignores = parser.compute_ignores(@ignores, @noignores)

      context = try_rules(
        parser,
        context_for_lr=nil,
        computed_ignores)

      if context.nil?
        Log.debug { "... :#{name} failed" }
        return nil
      end

      # try lr until fail
      loop do
        new_context = try_rules(
          parser,
          context_for_lr=context,
          computed_ignores)
        break if new_context.nil?
        context = new_context
      end

      Log.debug { "... :#{name} succeeded" }
      return context
    end
  end
end
