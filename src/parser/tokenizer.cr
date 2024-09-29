module Merlin::Tokenizer(IdentT)
  Log = ::Log.for("lang.tokenizer")

  def tokenize(
      str : String,
      filename : String? = nil) : Array(MatchedToken(IdentT))
    tokens_found = Array(MatchedToken(IdentT)).new
    row, col = 1, 1

    until str.empty?
      token_matched : Bool = @tokens.values.any? { |token|
        mdata = token.pattern.match(str)
        next false if mdata.nil?  # failure to `any?`

        # get value, first from group if exist, otherwise
        # from entire pattern
        value = mdata[1]?
        value = mdata[0] if value.nil?

        # create token
        position = Position.new(row, col, filename)
        token = MatchedToken(IdentT).new(token.name, value, position)
        tokens_found << token

        # skip past match
        str = mdata.post_match

        # update position
        rows = value.split(/(?:\r?\n)/, remove_empty: false)
        if rows.size == 1 && rows[0] == value
          col += rows[0].size
        else
          row += rows.size - 1
          col = rows.last.size + 1
        end

        true  # success to `any?`
      }

      unless token_matched
        position = Position.new(row, col, filename)
        raise Error::UnexpectedCharacter.new(str[0], position)
      end
    end

    return tokens_found
  end
end
