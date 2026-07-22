# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  class Converter
    def initialize(currency = MoneyAttribute.default_currency)
      @default_currency = currency
    end

    def parse(amount)
      case amount
      when Money, NilClass      then amount
      when Numeric              then Money.from(amount, @default_currency)
      when String               then Money.parse(amount, @default_currency)
      else raise ArgumentError, "Cannot convert #{amount.inspect} (#{amount.class}) to Money"
      end
    end

    alias call parse
  end
end
