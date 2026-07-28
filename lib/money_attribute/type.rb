# frozen_string_literal: true

module MoneyAttribute
  # Base type for money amount attributes. Handles casting and validation.
  class AmountType < ActiveRecord::Type::Value
    # Casts string input into a `Mint::Money` value.
    def cast(value) = value.is_a?(String) ? Money.parse(value, MoneyAttribute.default_currency) : super

    # Validates that the value is compatible with the fixed currency type.
    def assert_valid_value(value)
      case value
      when NilClass, Numeric, String then return
      when Mint::Money
        currency = MoneyAttribute.default_currency
        return if value.currency == currency

        message = "'#{value.inspect}' has different currency. Only #{currency.code} allowed."
      else
        message = "'#{value.inspect}' is not a valid type for the attribute."
      end
      raise ArgumentError, message
    end
  end

  # Type for integer columns storing subunits (e.g. cents).
  class IntegerAmountType < AmountType
    # Deserializes a subunit integer into a `Mint::Money` value.
    def deserialize(value) = value && Money.from_subunits(value, MoneyAttribute.default_currency)

    # Serializes a `Mint::Money` value into subunits.
    def serialize(value) = value&.subunits
  end

  # Type for decimal columns storing unit values (e.g. 12.34).
  class DecimalAmountType < AmountType
    # Deserializes a decimal value into a `Mint::Money` value.
    def deserialize(value) = value && Money.from(value, MoneyAttribute.default_currency)

    # Serializes a `Mint::Money` value into a decimal.
    def serialize(value) = value&.to_d
  end
end

ActiveSupport.on_load(:active_record) do
  include MoneyAttribute::Macro
  include MoneyAttribute::MoneyAmount
end
