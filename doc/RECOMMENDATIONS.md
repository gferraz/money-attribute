# Recommendations

This file collects practical ways to make `money_attribute` more useful while also pointing out public surface that looks removable or should be simplified.

## Completed

1. ~~Add richer query helpers for common money use cases.~~ ✅ Implemented.
   - `where_currency(price: 'EUR')` — filter by currency only (composite attributes).
   - `where_amount(price: 10.euros..100.euros)` — filter by amount only, any currency (raw numbers).
   - `order_by_amount(price: :desc)` — sorts by currency ASC then amount direction.
   - `sum_amount(:price)` — composite attributes: returns `Hash{String => Mint::Money}` when multiple currencies exist, single `Mint::Money` when one. Single-column attributes: always returns `Mint::Money`.
   - All use keyword hash syntax, available as class methods and relation methods.
   - Query logic split across `query/*.rb` sub-modules for maintainability.

## Remaining improvements

1. Consider simplifying `remove_money_amount` if custom removal column names are not needed.
   - The method accepts `options`, but usage of `options[:column]` is limited.
   - If no custom removal behavior is planned, a simpler signature would be easier to maintain.

## What works today

### Query helpers (built-in)

```ruby
# Amount + currency (Money objects)
Offer.where_money(price: 10.euros..100.euros)
# => WHERE price_amount BETWEEN 10 AND 100 AND price_currency = 'EUR'

Offer.where_money(price: 15.euros)
Offer.where_money(price: [10.euros, 20.euros, 30.euros])

# Currency only
Offer.where_currency(price: 'EUR')
# => WHERE price_currency = 'EUR'

# Amount only (any currency)
Offer.where_amount(price: 10..100)
# => WHERE price_amount BETWEEN 10 AND 100

# Ordering (currency ASC, amount direction)
Offer.order_by_amount(price: :desc)
# => ORDER BY price_currency ASC, price_amount DESC

# Sum — composite: single currency returns Mint::Money, multiple returns Hash
Offer.where_currency(price: 'EUR').sum_amount(:price)
# => Mint::Money(30.0, 'EUR')

Offer.sum_amount(:price)
# => { 'EUR' => Mint::Money(30.0, 'EUR'), 'USD' => Mint::Money(30.0, 'USD') }

# Single-column: always returns Mint::Money with default currency
SimpleOffer.sum_amount(:price)
# => Mint::Money(60.0, 'BRL')

# Multiple attributes — returns Hash of results
Offer.sum_amount(:price, :discount)
# => { price: { 'EUR' => Money, 'USD' => Money }, discount: Mint::Money }

# Chaining
Offer.where_currency(price: 'EUR')
     .where_amount(price: 10..100)
     .order_by_amount(price: :asc)
```

## Notes

- I would not remove `Type`, `Converter`, `Current`, or the migration helpers without replacing their behavior, because they are part of the public storage and assignment flow.
- The biggest immediate value was in query helpers, because they improve day-to-day usability without changing the core model API. ✅ Done.
