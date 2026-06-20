# frozen_string_literal: true

module MoneyAttribute
  class Parser
    def initialize(currency = MoneyAttribute.default_currency)
      @default_currency = currency
    end

    def parse(amount, currency = @default_currency)
      currency = ::Mint::Currency.resolve!(currency)
      case amount
      when NilClass    then nil
      when Numeric     then ::Mint::Money.from(amount, currency)
      when String      then ::Mint::Money.from(amount.to_r, currency)
      when ::Mint::Money
        return amount if amount.currency == currency

        raise TypeError, "Cannot automatically convert #{amount} to #{currency.code}"
      else
        ::Mint.parse(amount, currency)
      end
    end
    alias call parse
  end
end
