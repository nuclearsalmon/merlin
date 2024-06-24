module Merlin
  record Token(IdentT),
    _type : IdentT,
    pattern : Regex,
    greedy : Bool = false do

    def to_s
      ":#{@_type}(\"#{@value}\")"
    end
  end

  record MatchedToken(IdentT),
    _type : IdentT,
    value : String,
    position : Position do

    def to_s
      ":#{@_type}(\"#{@value}\") @ #{@position.to_s}"
    end
  end
end
