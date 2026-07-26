# frozen_string_literal: true

module MoneyAttribute
  # Resolves `order_by_amount` to ordered queries (currency ASC, amount direction).
  module AmountOrder
    def resolve_amount_order(attr, direction)
      spec = money_attribute_spec!(attr)

      if spec.composite?
        order(spec.currency_col => :asc, spec.amount_col => direction)
      else
        order(attr => direction)
      end
    end
  end
end
