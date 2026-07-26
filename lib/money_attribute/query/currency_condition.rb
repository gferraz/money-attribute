# frozen_string_literal: true

module MoneyAttribute
  # Resolves `where_currency` conditions to currency column queries.
  module CurrencyCondition
    def resolve_currency_condition(attr, currency)
      spec = money_attribute_spec!(attr)

      if spec.kind == :composite
        code = currency.is_a?(Mint::Money) ? currency.currency_code : currency.to_s
        where(spec.currency_col => code)
      else
        raise ArgumentError,
              "#{klass.name}.#{attr} is a single-column attribute (money_amount) with no currency column"
      end
    end
  end
end
