# frozen_string_literal: true

module MoneyAttribute
  # Type
  class Type < ActiveRecord::Type::Value
    # Initializes the type with the backing column type.
    def initialize(column_type: ActiveRecord::Type::Decimal.new)
      @integer_column = column_type.is_a?(ActiveRecord::Type::Integer)
      super()
    end

    # Casts string input into a `Money` value.
    def cast(value)
      if value.is_a?(String)
        Mint::Money.parse(value, MoneyAttribute.default_currency)
      else
        super
      end
    end

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
    def deserialize(value)
      return nil unless value

      currency = MoneyAttribute.default_currency

      if @integer_column
        Mint::Money.from_subunits(value, currency)
      else
        Mint::Money.from(value, currency)
      end
    end

    # Serializes a `Money` value into the column representation.
    def serialize(value)
      return nil unless value

      @integer_column ? value.subunits : value.to_d
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include MoneyAttribute::Macro
  include MoneyAttribute::MoneyAmount
end
