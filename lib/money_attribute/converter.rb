# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  class Converter
    def initialize(currency = MoneyAttribute.default_currency)
      @default_currency = currency
    end

    def parse(amount, currency = @default_currency)
      case amount
      when Mint::Money, NilClass then amount
      when Numeric               then Mint::Money.from(amount, currency)
      when String                then Money.parse(amount, currency)
      else raise ArgumentError, "Cannot convert #{amount.inspect} (#{amount.class}) to Money"
      end
    end
    alias call parse
  end
end
