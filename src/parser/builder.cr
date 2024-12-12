module Merlin
  class ParserBuilder(IdentT, NodeT)
    @root_name : IdentT? = nil
    @group_builders = Hash(IdentT, GroupBuilder(IdentT, NodeT)).new
    @tokens = Hash(IdentT, Token(IdentT)).new

    def self.new(&)
      instance = self.new
      with instance yield instance
      instance
    end

    #def initialize; end

    def with_self(&)
      with self yield
    end

    def build : Parser(IdentT, NodeT)
      # build groups
      groups = Hash(IdentT, Group(IdentT, NodeT)).new
      @group_builders.each { |name, builder|
        group = builder.build
        groups[name] = group
      }

      # ensure root was defined
      root = groups[@root_name]?
      raise Error::SyntaxFault.new("Undefined root") if root.nil?

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

    private def root(name : IdentT) : Nil
      raise Error::SyntaxFault.new(
        "root already defined"
      ) unless @root_name.nil?

      @root_name = name
    end

    private def group(name : IdentT, &) : Nil
      name_s = name.to_s

      raise Error::SyntaxFault.new(
        "group names must not be uppercase: #{name}"
      ) if Util.upcase?(name_s)
      raise Error::SyntaxFault.new(
        "duplicate group: :#{name}"
      ) if @group_builders.has_key?(name)

      builder = GroupBuilder(IdentT, NodeT).new(name)
      with builder yield
      @group_builders[name] = builder  # build later
    end
  end
end
