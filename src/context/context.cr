require "./modifying"
require "./querying"

class Merlin::Context(IdentT, NodeT)
  property name : IdentT

  @nodes : Deque(NodeT)?
  @tokens : Deque(MatchedToken(IdentT))?
  @sub_contexts : Hash(IdentT, Context(IdentT, NodeT))?

  def initialize(
      @name : IdentT,
      @nodes : Deque(NodeT)? = nil,
      @tokens : Deque(MatchedToken(IdentT))? = nil,
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
