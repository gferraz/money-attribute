# frozen_string_literal: true

module MoneyAttribute
  # Resolves `where_currency` conditions to currency column queries.
  module CurrencyCondition
    def resolve_currency_condition(attr, currency)
      reflection = klass.reflect_on_aggregation(attr)

      if reflection
        currency_col = reflection.mapping.keys.last
        code = currency.is_a?(Mint::Money) ? currency.currency_code : currency.to_s
        where(currency_col => code)
      elsif money_amount_attribute?(attr)
        raise ArgumentError,
              "#{klass.name}.#{attr} is a single-column attribute (money_amount) with no currency column"
      else
        raise ArgumentError, "#{attr} is not a money attribute on #{klass.name}"
      end
    end
  end
end
