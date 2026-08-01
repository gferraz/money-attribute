# frozen_string_literal: true

# Convenience method for converting numeric values to +Mint::Money+.
#
# @api private
class Numeric
  remove_method :to_money if method_defined?(:to_money)

  # Converts the numeric value to a +Mint::Money+ value.
  #
  # @param currency [String, Symbol, Mint::Currency, nil] the currency to use;
  #   falls back to {MoneyAttribute.default_currency}
  # @return [Mint::Money]
  # @example
  #   42.5.to_money('USD') # => Mint::Money(42.5, 'USD')
  def to_money(currency = MoneyAttribute.default_currency) = Money.from(self, currency)
end
