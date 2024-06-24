require "./tokenizer"
require "./validator"

module Merlin
  class Parser(IdentT, NodeT)
    include Tokenizer(IdentT)
    include ParserValidator(IdentT, NodeT)

    property reference_recursion_limit : Int32 = 1024

    protected getter root : Group(IdentT, NodeT)
    protected getter groups : Hash(IdentT, Group(IdentT, NodeT))
    protected getter tokens : Hash(IdentT, Token(IdentT))

    property parsing_position : Int32 = 0

    @parsing_tokens : \
      Array(MatchedToken(IdentT)) = \
      Array(MatchedToken(IdentT)).new

    @parsing_group_cache = \
      Hash(
        Int32,                       # start index
        Hash(
          IdentT,                    # identifier
          Tuple(
            Context(IdentT, NodeT),  # content
            Int32                    # end offset
      ))).new

    def initialize(
        @root : Group(IdentT, NodeT),
        @groups : Hash(IdentT, Group(IdentT, NodeT)),
        @tokens : Hash(IdentT, Token(IdentT)))
      validate_references_existance
      detect_and_fix_left_recursive_rules
      detect_unused_tokens
      detect_unused_groups
    end

    def parse(@parsing_tokens : Array(MatchedToken)) : NodeT
      # clear before parsing
      @parsing_position = 0
      @parsing_group_cache.clear()

      # parse
      result_context = @root.parse(self)

      if result_context.nil?
        raise Error::BadInput.new(
          "Parsing failed to match anything.")
      end

      result_node : NodeT = result_context.result

      # verify that every token was consumed
      position = @parsing_position
      if position < @parsing_tokens.size
        Log.debug {
          "Got #{result_node.pretty_inspect}, but only matched " +
          "#{position}/#{@parsing_tokens.size} tokens."
        }
        raise Error::UnexpectedCharacter.new(
          @parsing_tokens[position].value[0],
          @parsing_tokens[position].position)
      end

      return result_node
    end

    def compute_ignores(
        ignores : Array(IdentT)?,
        noignores : Array(IdentT)?) : Array(IdentT)
      final_ignores = Array(IdentT).new
      root_ignores = @root.ignores

      if noignores.nil?
        final_ignores.concat(root_ignores) unless root_ignores.nil?
      elsif noignores.size > 0
        unless root_ignores.nil?
          root_ignores.each { |ig_sym|
            next if !(noignores.nil?) && noignores.includes?(ig_sym)
            final_ignores << ig_sym
          }
        end
      end
      final_ignores.concat(ignores) unless ignores.nil?

      return final_ignores
    end

    def next_token(computed_ignores : Array(IdentT)) : MatchedToken(IdentT)?
      loop do
        token = @parsing_tokens[@parsing_position]?
        @parsing_position += 1
        if token.nil? || !(computed_ignores.includes?(token._type))
          return token
        end
      end
      return nil
    end

    def expect_token(
        ident : IdentT,
        computed_ignores : Array(IdentT)) : MatchedToken(IdentT)?
      initial_parsing_position = @parsing_position
      token = next_token(computed_ignores)

      if token.nil? || token._type != ident
        @parsing_position = initial_parsing_position
        return nil
      end
      return token
    end

    private def expect_cache(sym : IdentT) : Context(IdentT, NodeT)?
      cache_data = @parsing_group_cache[@parsing_position]?.try(&.[sym]?)
      return nil if cache_data.nil?

      cached_context, cached_token_length = cache_data
      @parsing_position += cached_token_length

      return cached_context.clone
    end

    private def save_to_cache(
        ident : IdentT,
        context : Context(IdentT, NodeT),
        start_position : Int32) : Nil
      number_of_tokens = @parsing_position - start_position

      cache_data = \
        Tuple(Context(IdentT, NodeT), Int32) \
        .new(context.clone, number_of_tokens)

      (@parsing_group_cache[start_position] ||=
        Hash(IdentT, Tuple(Context(IdentT, NodeT), Int32)).new) \
        [ident] = cache_data
    end

    def expect_group(
        ident : IdentT,
        computed_ignores : Array(IdentT)) : Context(IdentT, NodeT)?
      initial_parsing_position = @parsing_position

      context = nil
      loop do
        # try the cache
        context = expect_cache(ident)
        break unless context.nil? # break if we got a result
        # try parsing
        before_parsing_position = @parsing_position
        context = @groups[ident].parse(self)
        if context.nil?
          # get the first token and check if it should be ignored
          token = @parsing_tokens[@parsing_position]?
          break if token.nil?
          break unless computed_ignores.includes?(token._type)
          @parsing_position += 1
        else
          save_to_cache(ident, context, before_parsing_position)
          break
        end
      end

      if context.nil?
        # reset position if there's no match
        @parsing_position = initial_parsing_position
      end

      return context
    end

    def not_enough_tokens?(min_amount : Int32) : Bool
      @parsing_tokens[@parsing_position..].size < min_amount
    end

    def inspect_cache : String
      @parsing_group_cache.pretty_inspect
    end
  end
end
