module Merlin
  module ContextTemplate::Modifying(IdentT, NodeT)
    def clear : Nil
      @nodes.try(&.clear)
      @tokens.try(&.clear)
      @sub_contexts.try(&.clear)
    end

    def reset(name : IdentT) : Nil
      clear
      @name = name
    end

    protected def drop_token(index : Int32) : Nil
      if !((tokens = @tokens).nil?) && index < tokens.size
        tokens.delete_at(index)
      end
    end

    def drop_tokens : Nil
      @tokens.try(&.clear)
    end

    protected def drop_node(index : Int32) : Nil
      if !((nodes = @nodes).nil?) && index < nodes.size
        nodes.delete_at(index)
      end
    end

    def drop_nodes : Nil
      @nodes.try(&.clear)
    end

    def drop_context(key : IdentT) : Nil
      @sub_contexts.try(&.delete(key))
    end

    def drop_contexts : Nil
      @sub_contexts.try(&.clear)
    end

    def drop(key : IdentT) : Nil
      drop_context(key)
    end

    def drop(key : IdentT, index : Int32) : Nil
      context = self[key]?
      return if context.nil?

      if Util.upcase?(key)
        context.drop_token(index)
      else
        context.drop_node(index)
      end
    end

    def flatten : Nil
      @sub_contexts.try(&.each { |key, context|
        drop_context(key)
        context.flatten
        unsafe_merge(context)
      })
    end

    def absorb(key : IdentT) : Nil
      context = @sub_contexts.try(&.[key]?)
      return if context.nil?

      drop_context(key)
      unsafe_merge(context)
    end

    def become(key : IdentT) : Nil
      context = @sub_contexts.try(&.[key]?)
      return if context.nil?

      clear
      unsafe_merge(context)
    end

    def become(data : NodeT | MatchedToken(IdentT)) : Nil
      clear
      add(data)
    end

    private def internal_merge(
        from : Context(IdentT, NodeT),
        safe : ::Bool) : Nil
      unless (from_sub_contexts = from.@sub_contexts).nil? || from_sub_contexts.empty?
        if safe
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
          @nodes = safe ? from_nodes.dup : from_nodes
        else
          nodes.concat(from_nodes)
        end
      end

      unless (from_tokens = from.@tokens).nil? || from_tokens.empty?
        if (tokens = @tokens).nil?
          @tokens = safe ? from_tokens.dup : from_tokens
        else
          tokens.concat(from_tokens)
        end
      end
    end

    # safe merge, will clone and duplicate
    def merge(from : Context(IdentT, NodeT)) : Nil
      internal_merge(from, true)
    end

    # unsafe merge, will NOT clone and duplicate
    def unsafe_merge(from : Context(IdentT, NodeT)) : Nil
      internal_merge(from, false)
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

    # unsafe add, will NOT clone and duplicate
    def unsafe_add(
        key : IdentT,
        value : Context(IdentT, NodeT)) : Nil
      sub_contexts = @sub_contexts
      if sub_contexts.nil?
        (@sub_contexts = \
          Hash(IdentT, Context(IdentT, NodeT)).new
        )[key] = value
      else
        sub_context = sub_contexts[key]?
        if sub_context.nil?
          sub_contexts[key] = value
        else
          sub_context.unsafe_merge(value)
        end
      end
    end

    def add(
        key : IdentT,
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
end
