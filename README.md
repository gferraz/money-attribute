# Minting::Rails

[![CI](https://github.com/gferraz/minting-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/gferraz/minting-rails/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/minting-rails.svg)](https://badge.fury.io/rb/minting-rails)

Store and read Active Record attributes as `Mint::Money` objects with a single `money_attribute` declaration. No manual serialization, no boilerplate.

```ruby
class Product < ApplicationRecord
  money_attribute :price, currency: 'USD'   # fixed currency, single column
  money_attribute :total                    # multi-currency, two columns
end

Product.new(price: 12).price  # => #<Mint::Money USD 12.00>
```

## Quick start

```sh
bundle add minting-rails
bin/rails g mint:initializer
```

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  money_attribute :price, currency: 'USD'
end
```

That's it. `Product.new(price: 12).price` is a `Mint::Money`.

## Why Minting::Rails?

- **No serialization boilerplate** — declare once, read/write `Mint::Money` everywhere.
- **Two storage modes** — single column for fixed-currency apps (simpler), amount+currency columns for multi-currency records (more flexible).
- **Integer or decimal columns** — auto-detects the column type and adjusts serialization (e.g. integer stores cents, decimal stores unit value).
- **Normalizes everything** — pass a number, string, or `Mint::Money`; always get a `Mint::Money` back.
- **Currency enforcement** — fixed-currency attributes reject wrong currencies at assignment time.
- **Built on Rails primitives** — uses `ActiveRecord::Type`, `composed_of`, and `normalizes` under the hood. No monkey-patching of core classes.

## Requirements

- Ruby 3.3+
- Rails 7.1.3.2+
- [Minting](https://github.com/gferraz/minting) 1.6.0+

## Installation

```ruby
# Gemfile
gem 'minting-rails'
```

```sh
bundle install
bin/rails g mint:initializer
```

The generator creates `config/initializers/minting.rb`.

## Configuration

```ruby
# config/initializers/minting.rb
Mint.configure do |config|
  config.default_currency = 'USD'
  # enabled_currencies removed — all registered currencies are valid
end
```

See the [Minting gem](https://github.com/gferraz/minting) for full configuration options (custom currencies, formatting, rounding).

## Usage — Two modes

### Decision table

| | Fixed currency (single column) | Multi-currency (amount + currency) |
|---|---|---|
| **Migration** | `t.decimal :price` | `t.decimal :price_amount` + `t.string :price_currency` |
| **Model** | `money_attribute :price, currency: 'USD'` | `money_attribute :price` |
| **When to use** | Column always holds the same currency | Each row can hold a different currency |
| **Column type** | `decimal`, `integer`, or `bigint` | `decimal`, `integer`, or `bigint` for amount; `string` for currency |
| **Query** | `Product.where(price: 10.mint('USD'))` — full type support | `Offer.where(price: 10.mint('EUR'))` — equality only |

### Fixed currency (single column)

Migration:

```ruby
class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.decimal :price
      t.decimal :discount
      t.timestamps
    end
  end
end
```

Model:

```ruby
class Product < ApplicationRecord
  money_attribute :price, currency: 'USD'
  money_attribute :discount, currency: 'USD'
end
```

Assignments are normalized to `Mint::Money`:

```ruby
product = Product.new(price: 12, discount: '3.50')
product.price    # => #<Mint::Money USD 12.00>
product.discount # => #<Mint::Money USD 3.50>
```

A currency mismatch raises `ArgumentError`:

```ruby
Product.new(price: 12.to_money('EUR'))
# => ArgumentError: ... has different currency. Only USD allowed.
```

### Multi-currency (amount + currency columns)

Migration:

```ruby
class CreateOffers < ActiveRecord::Migration[7.1]
  def change
    create_table :offers do |t|
      t.decimal :price_amount
      t.string  :price_currency
      t.timestamps
    end
  end
end
```

Model:

```ruby
class Offer < ApplicationRecord
  money_attribute :price
end
```

The attribute is composed from `price_amount` and `price_currency`:

```ruby
offer = Offer.new(price: 15.to_money('EUR'))
offer.price          # => #<Mint::Money EUR 15.00>
offer.price_amount   # => 15.0
offer.price_currency # => "EUR"
```

When assigning a plain number or string, `Mint.default_currency` is used:

```ruby
offer = Offer.new(price: '12')
offer.price.currency.code # => "USD"
```

## Column type detection

Declare the column as `decimal`, `integer`, or `bigint` — the gem adapts:

```ruby
# Migration
create_table :orders do |t|
  t.bigint  :total_amount  # stored as cents (subunits)
  t.string  :total_currency
end

# Model
class Order < ApplicationRecord
  money_attribute :total
end

Order.new(total: 19.99.to_money('USD')).total_amount # => 1999
```

Same for fixed-currency attributes:

```ruby
# Migration
t.bigint :price

# Model (no change needed)
money_attribute :price, currency: 'USD'
```

> Use `integer`/`bigint` for large tables (faster, smaller). Use `decimal` when SQL-level readability matters.

## Custom column names

If your columns don't follow the `<name>_amount` / `<name>_currency` convention:

```ruby
class Invoice < ApplicationRecord
  money_attribute :total, mapping: {
    amount:   :total_amount,
    currency: :currency_code
  }
end
```

The mapping keys are `:amount` and `:currency`; values are your database column names.

## Querying

Fixed-currency attributes support Rails-native querying through the custom type:

```ruby
# Equality
Product.where(price: 10.mint('USD'))

# IN clause
Product.where(price: [10.mint('USD'), 20.mint('USD')])

# BETWEEN
Product.where(price: 10.mint('USD')..20.mint('USD'))

# Ordering
Product.order(price: :desc)

# Aggregation
Product.where(price: 10.mint('USD')).sum(:price)
```

Multi-currency attributes support equality queries via `composed_of`:

```ruby
Offer.where(price: 10.mint('EUR'))
```

For comparisons on multi-currency attributes, use the backing columns directly:

```ruby
Offer.where(price_amount: 10..20, price_currency: 'EUR')
Offer.where('price_amount > ? AND price_currency = ?', 10, 'EUR')
```

## Convenience methods

Minting::Rails adds small helpers on `Numeric` and `String`:

```ruby
12.to_money('USD')    # => #<Mint::Money USD 12.00>
12.dollars            # => #<Mint::Money USD 12.00>
12.euros              # => #<Mint::Money EUR 12.00>
'12.50'.mint('BRL')   # => #<Mint::Money BRL 12.50>
```

> If you prefer not to extend core classes, use `Mint::Money.money(12, 'USD')` instead.

## Development

```sh
bundle install
bundle exec rake test
```

The dummy Rails app under `test/dummy` exercises the engine in a full Rails environment.

## Contributing

Bug reports and pull requests welcome at [gferraz/minting-rails](https://github.com/gferraz/minting-rails).

## License

[MIT](MIT-LICENSE)
