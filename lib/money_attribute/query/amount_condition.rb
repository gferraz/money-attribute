# frozen_string_literal: true

module MoneyAttribute
  # Resolves `where_amount` conditions to amount column queries.
  module AmountCondition
    def resolve_amount_condition(attr, value)
      spec = money_attribute_spec!(attr)

      where(spec.amount_col => value)
    end
  end
end
