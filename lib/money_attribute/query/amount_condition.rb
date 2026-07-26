# frozen_string_literal: true

module MoneyAttribute
  # Resolves `where_amount` conditions to amount column queries.
  module AmountCondition
    def resolve_amount_condition(attr, value)
      spec = money_attribute_spec!(attr)

      if spec.kind == :composite
        resolve_composite_amount(spec, value)
      else
        where(attr => value)
      end
    end

    private

    def resolve_composite_amount(spec, value)
      amount_col = spec.amount_col

      case value
      when Range then where(arel_table[amount_col].between(value))
      else            where(amount_col => value)
      end
    end
  end
end
