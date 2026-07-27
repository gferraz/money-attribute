# frozen_string_literal: true

module MoneyAttribute
  # Resolves `where_currency` conditions to currency column queries.
  module CurrencyCondition
    # Builds a currency filter for the registered money attribute.
    def resolve_currency_condition(attr, currency)
      spec = money_attribute_spec!(attr)

      unless spec.composite?
        raise ArgumentError, "#{klass.name}.#{attr} is a money_amount attribute with no currency column"
      end

      code = currency.is_a?(Mint::Currency) ? currency.code : currency.to_s
      where(spec.currency_col => code)
    end
  end
end
