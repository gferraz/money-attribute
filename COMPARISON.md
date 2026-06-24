# MoneyAttribute vs money-rails

[Money-rails](https://github.com/RubyMoney/money-rails) is the most popular money-in-Rails gem. Here's how they compare side-by-side.

For a quick overview, see the [At a glance table](README.md#at-a-glance--vs-money-rails) in the README.

## Model declaration

```ruby
# MoneyAttribute
class Product < ApplicationRecord
  money_attribute :price, currency: 'USD'          # single column, fixed currency
  money_attribute :total                           # two columns (total_amount + total_currency), multi-currency
end

# money-rails
class Product < ApplicationRecord
  monetize :price_cents                            # single cents column, fixed currency
  monetize :total_cents, with_currency: :total_currency  # two columns, multi-currency
end
```

## Migration

```ruby
# MoneyAttribute — any numeric column type, t.money_attribute shorthand
create_table :products do |t|
  t.money_attribute   :price                     # decimal column, stores 12.34
  t.money_attribute   :discount, amount: { type: :integer }  # integer column, stores 1234 (cents)
  t.money_attribute   :total, amount: { type: :bigint }      # bigint + currency
end

# money-rails — integer cents only
create_table :products do |t|
  t.integer :price_cents        # stores 1234 (cents)
  t.integer :discount_cents     # stores 350 (cents)
  t.integer :total_cents
  t.string  :total_currency
end
```

## Reading & writing

```ruby
# MoneyAttribute — pass any type, always get Mint::Money
product.price = 12.34          # stores 12.34 in decimal column
product.price = 12.34           # stores 1234 in integer column
product.price = '$12.34'       # parses string
product.price                  # => [USD 12.34]

# money-rails — pass any type, always get Money
product.price_cents = 1234     # stores 1234
product.price = Money.new(1234, 'USD')
product.price                  # => #<Money fractional:1234 currency:USD>
```

## Querying

```ruby
# MoneyAttribute (fixed-currency) — full type-aware querying
Product.where(price: 10.to_money('USD'))
Product.where(price: [5.to_money('USD'), 10.to_money('USD')])
Product.where(price: 5.to_money('USD')..15.to_money('USD'))
Product.order(price: :desc)
Product.where(price: 10.to_money('USD')).sum(:price)

# money-rails — query through cents column
Product.where(price_cents: 1000)
Product.where(price_cents: [500, 1000])
Product.where(price_cents: 500..1500)
Product.order(:price_cents)
```

## Decimal columns

```ruby
# MoneyAttribute — works with decimal columns out of the box
# migration: t.decimal :price
money_attribute :price, currency: 'USD'

product.price = 12.34
product.price           # => [USD 12.34]
product.read_attribute(:price)  # => [USD 12.34]

# money-rails — no decimal column support
# migration: t.decimal :price  ← not supported
# Must use integer cents:
# migration: t.integer :price_cents
monetize :price_cents
product.price_cents = 1234
product.price           # => #<Money fractional:1234 currency:USD>
```

## Multi-currency

```ruby
# MoneyAttribute
money_attribute :price   # expects price_amount + price_currency columns

offer = Offer.new(price: 15.to_money('EUR'))
offer.price             # => [EUR 15.00]
offer.price_amount      # => 15.0
offer.price_currency    # => "EUR"

# money-rails
monetize :price_cents, with_currency: :price_currency

offer = Offer.new(price: Money.new(1500, 'EUR'))
offer.price             # => #<Money fractional:1500 currency:EUR>
offer.price_cents       # => 1500
offer.price_currency    # => "EUR"
```

## Column type auto-detection

```ruby
# MoneyAttribute — same declaration works with any column type
money_attribute :price, currency: 'USD'

# t.decimal :price   → stores human-readable value (12.34)
# t.integer :price   → stores cents (1234)
# t.bigint  :price   → stores cents (1234)

# money-rails — must always match the column name
monetize :price_cents   # column must be price_cents
monetize :price         # column must be price — no support for other types
```

## Performance

See [BENCHMARKS.md](BENCHMARKS.md) for detailed results across instantiation, persistence, reads, queries, arithmetic, and mass inserts. MoneyAttribute wins 9 of 11 benchmark cells, with the largest advantages in reads (up to 13× faster), arithmetic (3.7×), and mass inserts (1.5×).

## What money-rails has (and money_attribute doesn't)

MoneyAttribute is intentionally minimal — it focuses on storing and reading money attributes with Rails primitives. Money-rails is a more mature gem (12+ years, 1.9k stars) with a broader feature set that MoneyAttribute does not currently provide:

| Feature | money-rails | MoneyAttribute |
|---|---|---|
| **Mongoid support** | Yes | ActiveRecord only |
| **View helpers** | `humanized_money`, `money_without_cents`, etc. | None |
| **Currency exchange** | `default_bank`, `add_rate`, EuCentralBank | None |
| **Validation integration** | `validates_numericality_of` auto-added | Must add manually |
| **Per-request currency** | Lambda-based for multi-tenant apps | Static default only |
| **Allow nil** | `monetize :x, allow_nil: true` | Always allowed (no opt-in needed) |
| **Parse error control** | `raise_error_on_money_parsing` option | Always raises |
| **Community** | 1.9k stars, 386 forks, 897 commits | New gem, 1.0 soon |

If you need any of these features today, money-rails may be a better fit. MoneyAttribute fills a specific niche: a lightweight, performant money-in-Rails solution built on standard Rails primitives.
