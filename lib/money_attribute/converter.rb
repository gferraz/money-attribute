# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  class Converter
    # Initializes a converter with an optional fixed currency.
    def initialize(currency = nil)
      @static_currency = currency
    end

    # Converts raw input into a `Money` value.
    def parse(amount)
      currency = @static_currency || MoneyAttribute.default_currency
      case amount
      when Money, NilClass      then amount
      when Numeric              then Money.from(amount, currency)
      when String               then Money.parse(amount, currency)
      else raise ArgumentError, "Cannot convert #{amount.inspect} (#{amount.class}) to Money"
      end
    end

    alias call parse
  end
end
