module Merlin
  private class Rule(IdentT, NodeT)
    getter pattern : Array(IdentT)
    getter block   : Proc(Context(IdentT, NodeT), Nil)?

    def initialize(
        @pattern : Array(IdentT),
        @block : Proc(Context(IdentT, NodeT), Nil)? = nil)
      if @pattern.size < 1
        raise Error::SyntaxFault.new("A Rule cannot have an empty pattern.")
      end
    end
  end
end
