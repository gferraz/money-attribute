# frozen_string_literal: true

module MoneyAttribute
  class Parser
    def initialize(currency = MoneyAttribute.default_currency)
      @default_currency = currency
    end

    def parse(amount, currency = @default_currency)
      case amount
      when Mint::Money, NilClass then amount
      when Numeric               then Mint::Money.from(amount, currency)
      else                            Mint.parse(amount, currency)
      end
    end
    alias call parse
  end
end
