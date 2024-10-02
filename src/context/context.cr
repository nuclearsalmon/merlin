require "./modifying"
require "./querying"

private class Merlin::Context(IdentT, NodeT)
  property name : IdentT?

  def name_s : String
    (name = @name).nil? ? "<root>" : name.to_s
  end

  @nodes : Array(NodeT)?
  @tokens : Array(MatchedToken(IdentT))?
  @sub_contexts : Hash(IdentT, Context(IdentT, NodeT))?

  def initialize(
      @name : IdentT?,
      @nodes : Array(NodeT)? = nil,
      @tokens : Array(MatchedToken(IdentT))? = nil,
      @sub_contexts : Hash(IdentT, Context(IdentT, NodeT))? = nil)
  end

  def copy_with(
      name = @name.dup,
      nodes = @nodes.dup,
      tokens = @tokens.dup,
      sub_contexts = @sub_contexts.clone)
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
