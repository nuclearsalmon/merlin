class Merlin::Context(IdentT, NodeT)
  def clear : Nil
    @nodes.try(&.clear)
    @tokens.try(&.clear)
    @sub_contexts.try(&.clear)
  end

  def reset(name : IdentT?) : Nil
    clear
    @name = name
  end

  protected def drop_token(index : Int32) : MatchedToken(IdentT)?
    if !((tokens = @tokens).nil?) && index < tokens.size
      return tokens.delete_at(index)
    end
  end

  def drop_tokens : Nil
    @tokens.try(&.clear)
  end

  protected def drop_node(index : Int32) : NodeT?
    if !((nodes = @nodes).nil?) && index < nodes.size
      return nodes.delete_at(index)
    end
  end

  def drop_nodes : Nil
    @nodes.try(&.clear)
  end

  def drop_context(key : IdentT?) : Context(IdentT, NodeT)?
    @sub_contexts.try(&.delete(key))
  end

  def drop_contexts : Nil
    @sub_contexts.try(&.clear)
  end

  def drop(key : IdentT?) : Context(IdentT, NodeT)?
    drop_context(key)
  end

  def drop(key : IdentT?, index : Int32) : (NodeT | MatchedToken(IdentT))?
    context = self[key]?
    return if context.nil?
    if Util.upcase?(key)
      return context.drop_token(index)
    else
      return context.drop_node(index)
    end
  end

  def flatten : Nil
    @sub_contexts.try(&.each { |key, context|
      drop_context(key)
      context.flatten
      merge(context, clone: false)
    })
  end

  def absorb(key : IdentT?) : Nil
    context = self[key]
    drop_context(key)
    merge(context, clone: false)
  end

  def become(key : IdentT?) : Nil
    context = self[key]
    reset(key)
    merge(context, clone: false)
  end

  def become(value : NodeT | MatchedToken(IdentT)) : Nil
    clear
    add(value)
  end

  def to_subcontext(key : IdentT?) : Nil
    if Util.upcase?(key)
      tokens = @tokens
      return if tokens.nil? || tokens.size <= 0

      token = tokens.delete_at(0)
      sub_context = Context(IdentT, NodeT).new(
        name: key,
        tokens: [token])
      add(key, sub_context, clone: false)
    else
      nodes = @nodes
      return if nodes.nil? || nodes.size <= 0

      node = nodes.delete_at(0)
      sub_context = Context(IdentT, NodeT).new(
        name: key,
        nodes: [node])
      add(key, sub_context, clone: false)
    end
  end

  def subcontext_self(as_key : IdentT = @name.not_nil!) : Nil
    sub_context = copy_with(name: as_key)
    clear
    add(as_key, sub_context, clone: false)
  end

  #def rename_subcontext(
  #    from_key : IdentT?,
  #    to_key : IdentT?) : Nil
  #  sub_contexts = @sub_contexts
  #  return if sub_contexts.nil?
  #
  #  context = sub_contexts.delete(from_key)
  #  return if context.nil?
  #
  #  sub_contexts[to_key] = context
  #end

  def merge(
    from : Context(IdentT, NodeT),
    clone : Bool = true
  ) : Nil
    unless (from_sub_contexts = from.@sub_contexts).nil? || from_sub_contexts.empty?
      if clone
        from_sub_contexts = from_sub_contexts.clone
      end
      if (sub_contexts = @sub_contexts).nil?
        @sub_contexts = from_sub_contexts
      else
        sub_contexts.merge!(from_sub_contexts)
      end
    end

    unless (from_nodes = from.@nodes).nil? || from_nodes.empty?
      if (nodes = @nodes).nil?
        @nodes = clone ? from_nodes.dup : from_nodes
      else
        nodes.concat(from_nodes)
      end
    end

    unless (from_tokens = from.@tokens).nil? || from_tokens.empty?
      if (tokens = @tokens).nil?
        @tokens = clone ? from_tokens.dup : from_tokens
      else
        tokens.concat(from_tokens)
      end
    end
  end

  def add(value : NodeT) : Nil
    (@nodes ||= Array(NodeT).new) << value
  end

  def add(values : Array(NodeT)) : Nil
    (@nodes ||= Array(NodeT).new).concat(values)
  end

  def add(value : MatchedToken(IdentT)) : Nil
    (@tokens ||= Array(MatchedToken(IdentT)).new) << value
  end

  def add(values : Array(MatchedToken(IdentT))) : Nil
    (@tokens ||= Array(MatchedToken(IdentT)).new).concat(values)
  end

  def add(
    key : IdentT,
    value : Context(IdentT, NodeT),
    clone : Bool = true
  ) : Nil
    sub_contexts = @sub_contexts
    if sub_contexts.nil?
      (@sub_contexts = \
        Hash(IdentT, Context(IdentT, NodeT)).new
      )[key] = (clone ? value.clone : value)
    else
      sub_context = sub_contexts[key]?
      if sub_context.nil?
        sub_contexts[key] = (clone ? value.clone : value)
      else
        sub_context.merge(value, clone: clone)
      end
    end
  end

  def add(
      key : IdentT?,
      value : \
        NodeT | Array(NodeT) | \
        MatchedToken(IdentT) | Array(MatchedToken(IdentT))) : Nil
    sub_contexts = @sub_contexts
    if sub_contexts.nil?
      value_context = Context(IdentT, NodeT).new(key)
      value_context.add(value)
      (@sub_contexts = \
        Hash(IdentT, Context(IdentT, NodeT)).new
      )[key] = value_context
    else
      sub_context = sub_contexts[key]?
      if sub_context.nil?
        value_context = Context(IdentT, NodeT).new(key)
        value_context.add(value)
        sub_contexts[key] = value_context
      else
        sub_context.add(value)
      end
    end
  end
end
