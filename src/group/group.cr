module Merlin
  private class Group(IdentT, NodeT)
    getter name             : IdentT
    getter lr_rules         : Array(Rule(IdentT, NodeT))
    getter rules            : Array(Rule(IdentT, NodeT))
    getter optional         : Bool
    getter ignores          : Array(IdentT)?
    getter noignores        : Array(IdentT)?
    getter trailing_ignores : Array(IdentT)?
    getter inherited_ignores : Array(IdentT)?
    getter inherited_noignores : Array(IdentT)?
    getter inherited_trailing_ignores : Array(IdentT)?

    def initialize(
      @name             : IdentT,
      @lr_rules         : Array(Rule(IdentT, NodeT)),
      @rules            : Array(Rule(IdentT, NodeT)),
      @optional         : Bool,
      @ignores          : Array(IdentT)?,
      @noignores        : Array(IdentT)?,
      @trailing_ignores : Array(IdentT)?,
      @inherited_ignores : Array(IdentT)?,
      @inherited_noignores : Array(IdentT)?,
      @inherited_trailing_ignores : Array(IdentT)?)
    end
  end
end
