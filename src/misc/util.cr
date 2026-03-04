module Merlin::Util
  extend self

  macro upcase?(obj)
    ((%s = {{obj}}.to_s).upcase == %s)
  end

  macro downcase?(obj)
    ((%s = {{obj}}.to_s).downcase == %s)
  end

  macro single_deque(t, obj)
    Deque({{ t }}).new(initial_capacity: 1).tap &.push({{ obj }})
  end
end
