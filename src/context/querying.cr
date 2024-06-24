module Merlin
  module ContextTemplate::Querying(IdentT, NodeT)
    def []?(key : IdentT) : Context(IdentT, NodeT)?
      if key == @name
        self
      else
        @sub_contexts.try(&.[key]?)
      end
    end

    def [](key : IdentT) : Context(IdentT, NodeT)
      self.[]?(key) || raise Error::SyntaxFault.new(
        "Expected subcontext :#{key} for :#{@name} " +
        "not found. #{self.pretty_inspect}.")
    end

    def node?(index : Int32 = 0) : NodeT?
      @nodes.try(&.[index]?)
    end

    def node(index : Int32 = 0) : NodeT
      node?(index) || raise Error::SyntaxFault.new(
        "Expected node for :#{@name} not found. " +
        "#{self.pretty_inspect}.")
    end

    def nodes? : Array(NodeT)?
      @nodes.try(&.dup)
    end

    def nodes : Array(NodeT)
      nodes? || raise Error::SyntaxFault.new(
        "Expected nodes for :#{@name} not found.
        #{self.pretty_inspect}.")
    end

    def token?(index : Int32 = 0) : MatchedToken(IdentT)?
      @tokens.try(&.[index]?)
    end

    def token(index : Int32 = 0) : MatchedToken(IdentT)
      token?(index) || raise Error::SyntaxFault.new(
        "Expected token for :#{@name} not found. " +
        "#{self.pretty_inspect}.")
    end

    def tokens? : Array(MatchedToken(IdentT))?
      @tokens.try(&.dup)
    end

    def tokens : Array(MatchedToken(IdentT))
      tokens? || raise Error::SyntaxFault.new(
        "Expected tokens for :#{@name} not found. " +
        "#{self.pretty_inspect}.")
    end

    def empty? : ::Bool
      return false unless (tokens = @tokens).nil? || tokens.empty?
      return false unless (nodes = @nodes).nil? || nodes.empty?
      return false unless (sub_contexts = @sub_contexts).nil? || sub_contexts.empty?
      return true
    end

    # Root result
    def result : NodeT
      _tokens = @tokens
      _nodes = @nodes
      _sub_contexts = @sub_contexts
      unless _tokens.nil? || _tokens.empty?
        raise Error::SyntaxFault.new(
          "Root must return no tokens. #{pretty_inspect}")
      end
      unless _sub_contexts.nil? || _sub_contexts.empty?
        raise Error::SyntaxFault.new(
          "Root must return no subcontexts. #{pretty_inspect}")
      end

      if _nodes.nil? || _nodes.size < 1
        raise Error::SyntaxFault.new(
          "Root returned no Nodes. #{pretty_inspect}")
      end
      if _nodes.size > 1
        raise Error::SyntaxFault.new(
          "Root returned more than one Node. #{pretty_inspect}")
      end

      return _nodes.first
    end

    def position? : Position?
      lowest_position = nil

      @tokens.try(&.each { |token|
        token_position = token.position
        if (lowest_position.nil? ||
            (token_position.row <= lowest_position.row &&
            token_position.col < lowest_position.col))
          lowest_position = token_position
        end
      })

      @nodes.try(&.each { |node|
        node_position = node.position
        if (lowest_position.nil? ||
            (node_position.row <= lowest_position.row &&
            node_position.col < lowest_position.col))
          lowest_position = node_position
        end
      })

      sub_contexts = @sub_contexts
      unless sub_contexts.nil?
        sub_contexts.each { |_, sub_context|
          next if sub_context.empty?

          sub_context_position = sub_context.position?
          next if sub_context_position.nil?

          if (lowest_position.nil? ||
              (sub_context_position.row <= lowest_position.row &&
               sub_context_position.col < lowest_position.col))
            lowest_position = sub_context_position
          end
        }
      end

      return lowest_position
    end

    def position : Position
      lowest_position = position?

      if lowest_position.nil?
        if empty?
          raise Error::SyntaxFault.new(
            "Could not find a context position, " +
            "because it is empty.")
        else
          raise Error::SyntaxFault.new(
            "Could not find a context position, " +
            "yet context is not empty.")
        end
      end

      return lowest_position
    end
  end
end
