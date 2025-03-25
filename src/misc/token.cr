module Merlin
  record Token(IdentT),
    name : IdentT,
    pattern : Regex,
    adaptive : Bool = false do

    def to_s
      ":#{@name}"
    end
  end

  record MatchedToken(IdentT),
    name : IdentT,
    value : String,
    position : Position do

    def value_position
      {value: @value, position: @position}
    end

    def to_s
      "#{@name}(#{@value.inspect}) @ #{@position.to_s}"
    end
  end
end
