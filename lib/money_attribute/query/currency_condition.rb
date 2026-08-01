# frozen_string_literal: true

module MoneyAttribute
  # Internal currency-filter resolution for the +where_currency+ query helper.
  #
  # @api private
  module CurrencyCondition
    # Builds a currency filter for the registered money attribute.
    #
    # Only composite attributes have a currency column, so single-column
    # attributes raise.
    #
    # @param attr [Symbol] the money attribute name
    # @param currency [String, Mint::Currency] the currency code or object
    # @return [ActiveRecord::Relation]
    # @raise [ArgumentError] if the attribute is not a composite money attribute
    # @api private
    def resolve_currency_condition(attr, currency)
      spec = money_attribute_spec!(attr)

      unless spec.composite?
        raise ArgumentError, "#{klass.name}.#{attr} is a money_amount attribute with no currency column"
      end

      code = currency.is_a?(Mint::Currency) ? currency.code : currency.to_s
      where(spec.currency_column => code)
    end
  end
end
