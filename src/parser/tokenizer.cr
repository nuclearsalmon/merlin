module Merlin::Tokenizer(IdentT)
  Log = ::Log.for("lang.tokenizer")

  def tokenize(
      str : String,
      filename : String? = nil) : Array(MatchedToken(IdentT))
    tokens_found = Array(MatchedToken(IdentT)).new
    row, col = 1, 1
    tokens = @tokens.values

    until str.empty?
      token_matched : Bool = tokens.any? { |token|
        mdata = token.pattern.match(str)
        next false if mdata.nil?  # failure to `any?`

        # get value, first from group if exist, otherwise
        # from entire pattern
        value = mdata[1]?
        value = mdata[0] if value.nil?

        # create token
        position = Position.new(row, col, filename)
        token = MatchedToken(IdentT).new(token._type, value, position)
        Log.debug { "Matched token :#{token._type}: \"#{value}\"" }
        tokens_found << token

        # skip past match
        str = mdata.post_match

        # update position
        value.each_char { |char|
          if char == '\n'
            row += 1
            col = 1
          else
            col += 1
          end
        }

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
