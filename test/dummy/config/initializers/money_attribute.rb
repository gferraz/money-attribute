# encoding : utf-8

MoneyAttribute.configure do |config|

  # Register a custom currency
  #
  # Example:
  #   config.added_currencies = [
  #     {currency: 'CRC', subunit: 2, symbol: '₡'},
  #    {currency: 'NGN', subunit: 3, symbol: '₦'}
  #   ]
  config.added_currencies = [
    {currency: 'CRCA', subunit: 2, symbol: '₡'},
    {currency: 'NGNA', subunit: 3, symbol: '₦'}
  ]

  # To set the default currency
  #
  # It must be a registered currency
  #
  config.default_currency = 'BRL'

end