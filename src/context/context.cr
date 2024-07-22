require "./modifying"
require "./querying"


class Merlin::Context(IdentT, NodeT)
  property name : IdentT

  @nodes : Array(NodeT)?
  @tokens : Array(MatchedToken(IdentT))?
  @sub_contexts : Hash(IdentT, Context(IdentT, NodeT))?

  def initialize(
      @name : IdentT,
      @nodes : Array(NodeT)? = nil,
      @tokens : Array(MatchedToken(IdentT))? = nil,
      @sub_contexts : Hash(IdentT, Context(IdentT, NodeT))? = nil)
  end

  def copy_with(
      name = @name,
      nodes = @nodes,
      tokens = @tokens,
      sub_contexts = @sub_contexts)
    self.class.new(name, nodes, tokens, sub_contexts)
  end

  def clone
    self.class.new(
      @name.clone,
      @nodes.try(&.dup),
      @tokens.try(&.dup),
      @sub_contexts.try(&.clone))
  end
end
