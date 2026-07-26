# frozen_string_literal: true

module MoneyAttribute
  # Shared helpers for money attribute query modules.
  module QueryHelpers
    def money_attribute_spec!(attr)
      spec = klass.money_attribute_spec(attr)
      return spec if spec

      raise ArgumentError, "#{attr} is not a money attribute on #{klass.name}"
    end

    def build_money_value(raw_amount, currency, column)
      return raw_amount if raw_amount.is_a?(Mint::Money)
      return nil if raw_amount.nil?

      resolved = Money::Currency.resolve(currency)
      if klass.integer_column?(column)
        Mint::Money.from_subunits(raw_amount, resolved)
      else
        Mint::Money.from(raw_amount, resolved)
      end
    end
  end
end
