# Query Helpers

All helpers are defined as class methods on `ActiveRecord::Base` and instance
methods on `ActiveRecord::Relation`. Every helper looks up the registered
`AttributeSpec` first to determine single-column vs composite behavior.

## `where_currency(price: 'EUR')`

**Composite only.** Filters by the currency column. Raises on `money_amount`
attributes (no currency column). Accepts strings or `Mint::Currency` objects.

```ruby
Offer.where_currency(price: 'EUR')
# SELECT * FROM offers WHERE price_currency = 'EUR'
```

## `where_amount(price: 10..100)`

**Both modes.** Filters by the amount column. Accepts:

- **Scalar** -- `price: 10` or `price: 10.dollars`
- **Range** -- `price: 10..100` (inclusive end), `price: 10...100` (exclusive end)
- **Array** -- `price: [10, 30]` (IN clause)

For integer/subunit columns, `Mint::Money` values are automatically converted
to subunits (e.g., `10.dollars` -> `1000`).

```ruby
Offer.where_amount(price: 10..100)
# SELECT * FROM offers WHERE price_amount >= 10.0 AND price_amount <= 100.0
```

## `order_by_amount(price: :desc)`

**Both modes.** Orders by amount. Composite attributes sort by
`currency ASC, amount <dir>` so records group by currency first. Single-column
sorts by amount only. Defaults to `:asc`.

```ruby
Offer.order_by_amount(price: :desc)
# ORDER BY price_currency ASC, price_amount DESC
```

## `pluck_amount(:price)`

**Both modes.** Returns `Mint::Money` objects, following Rails arity
conventions:

| Args | Return |
|---|---|
| 1 attribute | `Array<Mint::Money>` |
| N attributes | `Array<Array>` (rows of `Mint::Money` values) |

Both single-column and composite attributes return `Mint::Money` objects.
For composite attributes, `Mint::Money` is reconstructed from
amount+currency columns. For single-column attributes, the custom
`Type#deserialize` wraps the raw value in `Mint::Money` using the
default currency.

```ruby
Offer.pluck_amount(:price)           # => [#<Money:0x... EUR 10>, #<Money:0x... USD 50>]
SimpleOffer.pluck_amount(:price)     # => [#<Money:0x... BRL 10>, #<Money:0x... BRL 50>]
```

## `pick_amount(:price)`

**Both modes.** Returns a single `Mint::Money` value from the first row
(or `nil`). Follows Rails `pick` semantics:

| Args | Return |
|---|---|
| 1 attribute | `Mint::Money` or `nil` |
| N attributes | `Array` of `Mint::Money` values or `nil` |

```ruby
Offer.order(:price).pick_amount(:price)  # => #<Money:0x... EUR 10>
Offer.where(price: nil).pick_amount(:price)  # => nil
```

## `sum_amount(:price)`

**Both modes. Takes exactly one attribute** (not splat). Always returns
`Array<Mint::Money>`:

- **Composite**: `GROUP BY currency_column`, sums per currency, sorted by
  currency code
- **Single-column**: sums directly, wraps with default currency
- **Empty result**: `[Mint::Money(0, default_currency)]`

```ruby
Offer.sum_amount(:price)
# => [Mint::Money(30.0, 'EUR'), Mint::Money(70.0, 'USD')]

Offer.where_currency(price: 'EUR').sum_amount(:price)
# => [Mint::Money(30.0, 'EUR')]
```

## Chaining

All helpers return `ActiveRecord::Relation` (except `pluck_amount`/`pick_amount`/
`sum_amount` which return values), so they chain naturally:

```ruby
Offer.where_currency(price: 'EUR')
     .where_amount(price: 10..50)
     .order_by_amount(price: :asc)
```

## Behavior by attribute mode

| Helper | Composite (`money_attribute`) | Single-column (`money_amount`) |
|---|---|---|
| `where_currency` | Filters by currency column | **Raises** -- no currency column |
| `where_amount` | Queries amount column | Queries amount column |
| `order_by_amount` | `currency ASC, amount <dir>` | `amount <dir>` |
| `pluck_amount` (1 attr) | `Array<Mint::Money>` | `Array<Mint::Money>` |
| `pick_amount` (1 attr) | `Mint::Money` or `nil` | `Mint::Money` or `nil` |
| `sum_amount` | `GROUP BY` currency, per-currency sums | Direct sum, default currency |
