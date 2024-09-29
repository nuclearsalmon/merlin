module Merlin
  class ParserBuilder(IdentT, NodeT)
    @root_ident : IdentT
    @root : Group(IdentT, NodeT)? = nil
    @group_builders = Array(GroupBuilder(IdentT, NodeT)).new
    @tokens = Hash(IdentT, Token(IdentT)).new

    def initialize(@root_ident : IdentT)
    end

    def self.new(root_ident : IdentT, &)
      instance = self.class.new(root_ident)
      with instance yield instance
      instance
    end

    def build : Parser(IdentT, NodeT)
      root = @root
      raise Error::SyntaxFault.new(
        "Undefined root"
      ) if root.nil?

      # build groups
      groups = Hash(IdentT, Group(IdentT, NodeT)).new
      @group_builders.each { |builder|
        group = builder.build(root)
        groups[group.name] = group
      }

      # build parser
      Parser(IdentT, NodeT).new(root, groups, @tokens)
    end

    private def token(
      name : IdentT,
      pattern : Regex,
      adaptive : Bool = false
    ) : Nil
      name_s = name.to_s

      raise Error::SyntaxFault.new(
        "name must be uppercase: #{name}"
      ) unless Util.upcase?(name_s)
      raise Error::SyntaxFault.new(
        "duplicate token: :#{name}"
      ) if @tokens[name]?

      token = Token(IdentT).new(
        name,
        Regex.new("\\A(?:#{ pattern.source })"),
        adaptive)

      @tokens[name] = token
    end

    private def root(&) : Nil
      raise Error::SyntaxFault.new(
        "root already defined"
      ) unless @root.nil?

      builder = GroupBuilder(IdentT, NodeT).new(@root_ident)
      with builder yield
      @root = builder.build(with_root: nil)
    end

    private def group(name : IdentT, &) : Nil
      name_s = name.to_s

      raise Error::SyntaxFault.new(
        "name must be lowercase: #{name}"
      ) unless Util.downcase?(name_s)
      raise Error::SyntaxFault.new(
        "duplicate group: :#{name}"
      ) if @group_builders.any? { |builder| builder.name == name }

      builder = GroupBuilder(IdentT, NodeT).new(name)
      with builder yield
      @group_builders << builder  # build later
    end
  end
end
