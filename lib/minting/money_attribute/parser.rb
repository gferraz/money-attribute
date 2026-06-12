# frozen_string_literal: true

module Mint
  # MoneyAttribute
  module MoneyAttribute
    class Parser
      def initialize(currency = Mint.default_currency)
        @default_currency = currency
      end

      def parse(amount, currency = @default_currency)
        currency = Mint.assert_valid_currency!(currency)
        case amount
        when NilClass    then nil
        when Numeric     then Mint::Money.create(amount, currency)
        when String      then Mint::Money.create(amount.to_r, currency)
        when Mint::Money
          return amount if amount.currency == currency

          raise TypeError, "Cannot automatically convert #{amount} to #{currency.code}"
        else
          Mint.parse(amount, currency)
        end
      end
      alias_method  :call, :parse
    end
  end
end
