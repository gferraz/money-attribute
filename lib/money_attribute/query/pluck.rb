# frozen_string_literal: true

module MoneyAttribute
  # Plucks amount values from money-aware attributes.
  module PluckAmount
    def pluck_amount(attr)
      raise ArgumentError, 'No attribute specified' if attr.nil?

      reflection = klass.reflect_on_aggregation(attr)

      if reflection
        resolve_composite_pluck(reflection)
      elsif money_amount_attribute?(attr)
        pluck(attr)
      else
        raise ArgumentError, "#{attr} is not a money attribute on #{klass.name}"
      end
    end

    private

    def resolve_composite_pluck(reflection)
      amount_col, currency_col = reflection.mapping.keys

      pluck(amount_col, currency_col).map do |amount, currency|
        build_money_value(amount, currency, amount_col)
      end
    end
  end
end
