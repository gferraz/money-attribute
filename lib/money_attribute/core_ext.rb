# frozen_string_literal: true

# :nodoc
class Numeric
  def to_money(currency = MoneyAttribute.default_currency)
    ::Mint.money(self, currency)
  end

  def dollars
    ::Mint.money(self, 'USD')
  end

  def euros
    ::Mint.money(self, 'EUR')
  end

  alias dollar dollars
  alias euro euros
end

# :nodoc
class String
  def to_money(currency = MoneyAttribute.default_currency)
    ::Mint.money(to_r, currency)
  end
end
