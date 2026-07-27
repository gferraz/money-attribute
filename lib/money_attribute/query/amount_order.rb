# frozen_string_literal: true

module MoneyAttribute
  # Resolves `order_by_amount` to ordered queries (currency ASC, amount direction).
  module AmountOrder
    # Builds an amount ordering for the registered money attribute.
    def resolve_amount_order(attr, direction)
      spec = money_attribute_spec!(attr)

      if spec.composite?
        order(spec.currency_col => :asc, spec.amount_col => direction)
      else
        order(spec.amount_col => direction)
      end
    end
  end
end
