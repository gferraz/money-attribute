# encoding : utf-8
# frozen_string_literal: true

MoneyAttribute.configure do |config|
  # Register a custom currency
  #
  # Example:
  #   config.added_currencies = [
  #     {currency: 'ZCRC', subunit: 2, symbol: '₡'},
  #    {currency: 'ZNGN', subunit: 3, symbol: '₦'}
  #   ]
  config.added_currencies = []

  # To set the default currency
  #
  # It must be a registered currency
  #
  config.default_currency = 'USD'
end
