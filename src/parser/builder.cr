module Merlin
  class ParserBuilder(IdentT, NodeT)
    @root : Group(IdentT, NodeT)? = nil
    @groups = Hash(IdentT, Group(IdentT, NodeT)).new
    @tokens = Hash(IdentT, Token(IdentT)).new

    def self.new(&)
      instance = self.class.new
      with instance yield instance
      instance
    end

    def build : Parser(IdentT, NodeT)
      root = @root
      raise Error::SyntaxFault.new(
        "Undefined root"
      ) if root.nil?

      return Parser(IdentT, NodeT).new(root, @groups, @tokens)
    end

    private def token(
        name : IdentT,
        pattern : Regex,
        greedy : Bool = false) : Nil
      name_s = name.to_s

      raise Error::SyntaxFault.new(
        "name must be uppercase: #{name}"
      ) unless Util.upcase?(name_s)
      raise Error::SyntaxFault.new(
        "duplicate token: :#{name}"
      ) if @tokens[name]?

      @tokens[name] = Token(IdentT).new(
        name,
        Regex.new("\\A" + pattern.source),
        greedy)
    end

    private def root(&) : Nil
      raise Error::SyntaxFault.new(
        "root already defined"
      ) unless @root.nil?

      builder = GroupBuilder(IdentT, NodeT).new(:root)
      with builder yield
      @root = builder.build
    end

    private def group(name : IdentT, &) : Nil
      name_s = name.to_s

      raise Error::SyntaxFault.new(
        "name must be lowercase: #{name}"
      ) unless Util.downcase?(name_s)
      raise Error::SyntaxFault.new(
        "duplicate group: :#{name}"
      ) if @groups[name]?

      builder = GroupBuilder(IdentT, NodeT).new(name)
      with builder yield
      @groups[name] = builder.build
    end
  end
end
