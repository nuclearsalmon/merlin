module Merlin
  private class Group(IdentT, NodeT)
    getter name             : IdentT
    getter lr_rules         : Array(Rule(IdentT, NodeT))
    getter rules            : Array(Rule(IdentT, NodeT))
    getter optional         : Bool
    getter computed_ignores : Array(IdentT)?
    getter trailing_ignores : Array(IdentT)?

    def initialize(
      @name             : IdentT,
      @lr_rules         : Array(Rule(IdentT, NodeT)),
      @rules            : Array(Rule(IdentT, NodeT)),
      @optional         : Bool,
      @computed_ignores : Array(IdentT)?,
      @trailing_ignores : Array(IdentT)?)
    end
  end
end
