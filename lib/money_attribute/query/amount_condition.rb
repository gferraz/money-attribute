# frozen_string_literal: true

module MoneyAttribute
  # Resolves `where_amount` conditions to amount column queries.
  module AmountCondition
    # Builds an amount filter for the registered money attribute.
    def resolve_amount_condition(attr, value)
      spec = money_attribute_spec!(attr)
      col = arel_table[spec.amount_col]

      condition = case value
                  when Range then col.between(value)
                  when Array then col.in(value)
                  else col.eq(value)
                  end

      where(condition)
    end
  end
end
