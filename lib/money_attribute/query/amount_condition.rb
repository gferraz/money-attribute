# frozen_string_literal: true

module MoneyAttribute
  # Resolves `where_amount` conditions to amount column queries.
  module AmountCondition
    def resolve_amount_condition(attr, value)
      reflection = klass.reflect_on_aggregation(attr)

      if reflection
        resolve_composite_amount(reflection, value)
      elsif money_amount_attribute?(attr)
        where(attr => value)
      else
        raise ArgumentError, "#{attr} is not a money attribute on #{klass.name}"
      end
    end

    private

    def resolve_composite_amount(reflection, value)
      amount_col = reflection.mapping.keys.first

      case value
      when Range then where(arel_table[amount_col].between(value))
      else            where(amount_col => value)
      end
    end
  end
end
