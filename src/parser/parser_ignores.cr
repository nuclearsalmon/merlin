module Merlin::ParserIgnores(IdentT, NodeT)
  private def consume_trailing_ignores(
    trailing_ignores : Array(IdentT)?
  ) : Nil
    return if trailing_ignores.nil?

    # consume all
    next_token(trailing_ignores)
    # step back so next call can get the not-ignored token
    @parsing_position -= 1
  end

  private def compute_new_ignores(
    current_ignores : Array(IdentT)?,
    group : Group(IdentT, NodeT)
  ) : Array(IdentT)
    new_ignores = current_ignores.nil? ? [] of IdentT : current_ignores.dup

    # Apply inherited ignores
    unless (inherited_ignores = group.inherited_ignores).nil?
      new_ignores.concat(inherited_ignores)
    end

    # Remove inherited noignores
    unless (inherited_noignores = group.inherited_noignores).nil?
      new_ignores.reject! { |ig| inherited_noignores.includes?(ig) }
    end

    # Apply local ignores (overriding inherited ones)
    unless (group_ignores = group.ignores).nil?
      new_ignores.concat(group_ignores)
    end

    # Remove local noignores (overriding inherited ones)
    unless (group_noignores = group.noignores).nil?
      new_ignores.reject! { |ig| group_noignores.includes?(ig) }
    end

    new_ignores.uniq!
    new_ignores
  end

  private def compute_new_trailing_ignores(
    current_trailing_ignores : Array(IdentT)?,
    group : Group(IdentT, NodeT)
  ) : Array(IdentT)
    new_trailing_ignores = current_trailing_ignores.nil? ? [] of IdentT : current_trailing_ignores.dup

    # Apply inherited trailing ignores
    unless (inherited_trailing_ignores = group.inherited_trailing_ignores).nil?
      new_trailing_ignores.concat(inherited_trailing_ignores)
    end

    # Apply local trailing ignores (overriding inherited ones)
    unless (group_trailing_ignores = group.trailing_ignores).nil?
      new_trailing_ignores.concat(group_trailing_ignores)
    end

    new_trailing_ignores.uniq!
    new_trailing_ignores
  end
end