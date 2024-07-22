class Merlin::Context(IdentT, NodeT)
  def []?(key : IdentT) : Context(IdentT, NodeT)?
    context = @sub_contexts.try(&.[key]?)
    if context.nil? && key == @name
      self
    else
      context
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

    _nodes.first
  end

  private def position?(lowest : Bool = true) : Position?
    position = nil

    @tokens.try(&.each { |token|
      other_position = token.position
      if (position.nil? ||
          (lowest && other_position < position) ||
          (!lowest && other_position > position))
        position = other_position
      end
    })

    @nodes.try(&.each { |node|
      other_position = node.position
      if (position.nil? ||
          (lowest && other_position < position) ||
          (!lowest && other_position > position))
        position = other_position
      end
    })

    sub_contexts = @sub_contexts
    unless sub_contexts.nil?
      sub_contexts.each { |_, sub_context|
        next if sub_context.empty?
        other_position = sub_context.position?(lowest)
        next if other_position.nil?
        if (position.nil? ||
            (lowest && other_position < position) ||
            (!lowest && other_position > position))
          position = other_position
        end
      }
    end

    position
  end

  private def position(lowest : Bool = true) : Position
    position = position?(lowest)
    if position.nil?
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

    position
  end

  def first_position : Position
    position(true)
  end

  def first_position? : Position?
    position?(true)
  end

  def last_position : Position
    position(false)
  end

  def last_position? : Position?
    position?(false)
  end

  def after_last_position : Position
    pos = position(false)
    pos.clone(col: pos.col + 1)
  end

  def after_last_position? : Position?
    pos = position?(false)
    pos.clone(col: pos.col + 1)
  end
end
