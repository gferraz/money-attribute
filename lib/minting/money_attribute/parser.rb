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
        when Mint::Money then amount
        when Numeric     then Mint::Money.create(amount, currency)
        when String      then Mint::Money.create(amount.to_r, currency)
        else
          if amount.respond_to? :to_money
            amount.to_money(currency)
          else
            Mint.parse(amount, currency)
          end
        end
      end
      alias_method  :call, :parse
    end
  end
end
