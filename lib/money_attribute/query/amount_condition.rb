# frozen_string_literal: true

module MoneyAttribute
  # Resolves `where_amount` conditions to amount column queries.
  module AmountCondition
    # Builds an amount filter for the registered money attribute.
    def resolve_amount_condition(attr, value)
      spec = money_attribute_spec!(attr)

      where(spec.amount_col => value)
    end
  end
end
