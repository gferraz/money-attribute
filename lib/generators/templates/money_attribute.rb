# encoding : utf-8
# frozen_string_literal: true

MoneyAttribute.configure do |config|
  # To set the default currency
  #
  # It must be a registered currency
  #
  config.default_currency = 'USD'

  # Register built-in crypto currencies
  #
  # 1. Register specific crypto currencies:
  #   Mint::Currency.register_crypto('BTC', 'ETH')
  #
  # 2. Register all built-in crypto currencies at once:
  #   Mint::Currency.register_all_crypto
  #
  # See available crypto currencies:
  #   Mint::Currency.crypto_currencies

  # Register a custom currency
  #
  # Example:
  #   config.added_currencies = [
  #    {currency: 'ZCRC', subunit: 2, symbol: '₡'},
  #    {currency: 'ZNGN', subunit: 3, symbol: '₦'}
  #   ]
  config.added_currencies = []
end
