# frozen_string_literal: true

module Mint
  # MintMoneyType
  class MintMoneyType < ActiveRecord::Type::Value
    def initialize(currency:, column_type: ActiveRecord::Type::Decimal.new)
      @currency = currency
      @column_type = column_type
      super()
    end

    def assert_valid_value(value)
      case value
      when NilClass, Numeric, String then return
      when Mint::Money
        return if value.currency == @currency

        message = "'#{value.inspect}' has different currency. Only #{@currency.code} allowed."
      else
        message = "'#{value.inspect}' is not a valid type for the attribute."
      end
      raise ArgumentError, message
    end

    def deserialize(value)
      value && Mint.money(value, @currency)
    end

    def serialize(value)
      return nil unless value

      if @column_type.is_a?(ActiveRecord::Type::Integer)
        value.fractional
      else
        value.to_d
      end
    end

    def self.type
      :mint_type
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.include Mint::MoneyAttribute
  ActiveRecord::Type.register(:mint_money, Mint::MintMoneyType)
end
