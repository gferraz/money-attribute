# encoding : utf-8

MoneyAttribute.configure do |config|
  config.added_currencies = [
    {currency: 'CRCA', subunit: 2, symbol: '₡'},
    {currency: 'NGNA', subunit: 3, symbol: '₦'}
  ]

  config.default_currency = 'BRL'
end
