# frozen_string_literal: true

module MoneyAttribute
  # Type
  class Type < ActiveRecord::Type::Value
    def initialize(currency:, column_type: ActiveRecord::Type::Decimal.new)
      @currency = currency
      @column_type = column_type
      super()
    end

    def assert_valid_value(value)
      case value
      when NilClass, Numeric, String then return
      when ::Mint::Money
        return if value.currency == @currency

        message = "'#{value.inspect}' has different currency. Only #{@currency.code} allowed."
      else
        message = "'#{value.inspect}' is not a valid type for the attribute."
      end
      raise ArgumentError, message
    end

    def deserialize(value)
      return nil unless value

      if @column_type.is_a?(ActiveRecord::Type::Integer)
        ::Mint::Money.from_subunits(value, @currency)
      else
        ::Mint::Money.from(value, @currency)
      end
    end

    def serialize(value)
      return nil unless value

      if @column_type.is_a?(ActiveRecord::Type::Integer)
        value.subunits
      else
        value.to_d
      end
    end

    def self.type
      :money
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include MoneyAttribute::Macro

  ActiveRecord::Type.register(:money, MoneyAttribute::Type)
end
