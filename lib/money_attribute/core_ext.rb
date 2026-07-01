# frozen_string_literal: true

# :nodoc
class Numeric
  remove_method :to_money if method_defined?(:to_money)

  def to_money(currency = MoneyAttribute.default_currency) = Mint.money(self, currency)
end

# :nodoc
class String
  remove_method :to_money if method_defined?(:to_money)

  def to_money(currency = MoneyAttribute.default_currency) = Mint.parse(self, currency)
end
