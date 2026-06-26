# frozen_string_literal: true

# :nodoc
class Numeric
  def to_money(currency = MoneyAttribute.default_currency) = Mint.money(self, currency)

  def dollars = Mint.money(self, 'USD')

  def euros = Mint.money(self, 'EUR')

  alias dollar dollars
  alias euro euros
end

# :nodoc
class String
  def to_money(currency = MoneyAttribute.default_currency) = Mint.parse(self, currency)
end
