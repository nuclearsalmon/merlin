module Merlin
  record Token(IdentT),
    name : IdentT,
    pattern : Regex,
    greedy : Bool = false do

    def to_s
      ":#{@name}"
    end
  end

  record MatchedToken(IdentT),
    name : IdentT,
    value : String,
    position : Position do

    def to_s
      "#{@name}(#{@value.inspect}) @ #{@position.to_s}"
    end
  end
end
