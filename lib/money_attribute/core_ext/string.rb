# frozen_string_literal: true

# Convenience method for parsing +Mint::Money+ from strings.
#
# @api private
class String
  remove_method :to_money if method_defined?(:to_money)

  # Parses the string into a +Mint::Money+ value.
  #
  # @param currency [String, Symbol, Mint::Currency, nil] the currency to use;
  #   falls back to {MoneyAttribute.default_currency}
  # @return [Mint::Money]
  # @raise [ArgumentError] if the string cannot be parsed
  # @example
  #   '12.34'.to_money('USD') # => Mint::Money(12.34, 'USD')
  def to_money(currency = MoneyAttribute.default_currency) = Money.parse(self, currency)
end
