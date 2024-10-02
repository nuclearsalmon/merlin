module Merlin
  private class Cache(IdentT, NodeT)
    @group_cache = Hash(
      Int32,                                     # start index
      Hash(                                      # location
        IdentT,                                  # identifier
        NamedTuple(                              # location entry
          context:      Context(IdentT, NodeT),  # content
          nr_of_tokens: Int32                    # number of tokens
    ))).new

    delegate clear, to: @group_cache

    private def new_location
      Hash(
        IdentT,
        NamedTuple(
          context: Context(IdentT, NodeT),
          nr_of_tokens: Int32
        )
      ).new
    end

    private def new_location_entry(
      context      : Context(IdentT, NodeT),
      nr_of_tokens : Int32
    )
      NamedTuple.new(
        context: context,
        nr_of_tokens: nr_of_tokens
      )
    end

    def store(
      ident            : IdentT,
      context          : Context(IdentT, NodeT),
      start_position   : Int32,
      parsing_position : Int32
    ) : Nil
      nr_of_tokens = parsing_position - start_position
      location = (@group_cache[start_position] ||= new_location())
      prev_entry = location[ident]?

      if prev_entry.nil? || (nr_of_tokens >= prev_entry[:nr_of_tokens])
        #puts "==="
        #puts "storing #{ident} at #{start_position}, consisting of #{nr_of_tokens} tokens"
        #puts "==="
        location[ident] = new_location_entry(context.clone, nr_of_tokens)
      end
    end

    def [](
      start_position : Int32,
      ident : IdentT
    ) : NamedTuple(
      context: Context(IdentT, NodeT),
      nr_of_tokens: Int32
    )?
      @group_cache[start_position]?.try(&.[ident]?)
    end
  end
end