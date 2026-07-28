# frozen_string_literal: true

module MoneyAttribute
  # Type
  class Type < ActiveRecord::Type::Value
    # Initializes the type with the backing column type.
    def initialize(column_type: :decimal)
      if column_type == :integer
        @deserializer = :from_subunits
        @serializer = :subunits
      else
        @deserializer = :from
        @serializer = :to_d
      end
      super()
    end

    # Casts string input into a `Money` value.
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

    # Deserializes the database value into a `Money` value.
    def deserialize(value) = value && Money.public_send(@deserializer, value, MoneyAttribute.default_currency)

    # Serializes a `Money` value into the column representation.
    def serialize(value) = value&.public_send(@serializer)
  end
end

ActiveSupport.on_load(:active_record) do
  include MoneyAttribute::Macro
  include MoneyAttribute::MoneyAmount
end
