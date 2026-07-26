# frozen_string_literal: true

module MoneyAttribute
  # Resolves `order_by_amount` to ordered queries (currency ASC, amount direction).
  module AmountOrder
    def resolve_amount_order(attr, direction)
      reflection = klass.reflect_on_aggregation(attr)

      if reflection
        currency_col = reflection.mapping.keys.last
        amount_col = reflection.mapping.keys.first
        order(currency_col => :asc, amount_col => direction)
      elsif money_amount_attribute?(attr)
        order(attr => direction)
      else
        raise ArgumentError, "#{attr} is not a money attribute on #{klass.name}"
      end
    end
  end
end
