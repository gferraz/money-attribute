# MoneyAttribute

[![CI](https://github.com/gferraz/money-attribute/actions/workflows/ci.yml/badge.svg)](https://github.com/gferraz/money-attribute/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/money_attribute.svg)](https://badge.fury.io/rb/money_attribute)

Store and read Active Record attributes as `Mint::Money` objects with no manual serialization. Two explicit helpers — one per storage mode:

```ruby
class Product < ApplicationRecord
  money_amount :price, currency: 'USD'     # fixed currency, one column
  money_attribute :total                   # multi-currency, two columns
end

Product.new(price: 12).price  # => [USD 12.00]
```

## Table of contents

- [Quick start](#quick-start)
- [Why MoneyAttribute](#why-moneyattribute)
- [Requirements](#requirements)
- [Installation](#installation)
- [Migration helpers](#migration-helpers)
- [Configuration](#configuration)
- [Usage — two modes](#usage--two-modes)
- [Column type detection](#column-type-detection)
- [Custom column names](#custom-column-names)
- [Column resolution](#column-resolution)
- [Querying](#querying)
- [Convenience methods](#convenience-methods)
- [Form helpers](#form-helpers)
- [Roadmap](#roadmap)
- [Development & Contributing](#development)
- [License](#license)

## Quick start

```sh
bundle add money_attribute
bin/rails g money_attribute:initializer
```

```ruby
# db/migrate/20260620000000_create_products.rb
class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.money_amount :price           # decimal(20,4), no currency column
      t.timestamps
    end
  end
end
```

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  money_amount :price, currency: 'USD'
end
```

That's it. `Product.new(price: 12).price` is a `Mint::Money`.

## Why MoneyAttribute?

- **No serialization boilerplate** — declare once, read/write `Mint::Money` everywhere.
- **Two storage modes** — single column for fixed-currency apps (simpler), amount+currency columns for multi-currency records (more flexible).
- **Integer or decimal columns** — auto-detects the column type and adjusts serialization (e.g. integer stores cents, decimal stores unit value).
- **Normalizes everything** — pass a number, string, or `Mint::Money`; always get a `Mint::Money` back.
- **Currency enforcement** — fixed-currency attributes reject wrong currencies at assignment time.
- **Built on Rails primitives** — uses `ActiveRecord::Type`, `composed_of`, and `normalizes` under the hood. No monkey-patching of core classes.

### At a glance — vs money-rails

| Feature | MoneyAttribute | money-rails |
|---|---|---|
| **Declare** | `t.money_amount :price` / `money_amount :price` or `t.money_attribute :price` / `money_attribute :price` | `monetize :price_cents` |
| **Column types** | `integer`, `decimal`, `bigint` — auto-detected | `integer` cents only |
| **Storage modes** | Single column, composite (amount+currency) | Single cents column, composite (cents+currency) |
| **Decimal columns** | Native — `t.decimal :price` | Not supported — must convert to cents manually |
| **Multi-currency** | `money_attribute :price` (convention: `<name>_amount` + `<name>_currency`) | `monetize :price_cents, with_currency: :price_currency` |
| **Rails integration** | `ActiveRecord::Type` + `composed_of` — no monkey-patches | `monetize` overrides reader/writer methods |
| **Query (fixed)** | `Model.where(price: money)` — `=`, `IN`, `BETWEEN`, `ORDER`, `SUM` | Through cents column (`price_cents`) |
| **Query (multi)** | `Model.where(price: money)` | `Model.where(price_cents:, price_currency:)` |
| **Internal amount** | `Rational` | `BigDecimal` |
| **Performance** | See [BENCHMARKS.md](BENCHMARKS.md) — wins 9/11 cells | — |

For a detailed side-by-side comparison, see [COMPARISON.md](COMPARISON.md).

## Requirements

- Ruby 3.3+
- Rails 7.1.3.2+
- [Minting](https://github.com/gferraz/minting) 1.8.0+

## Installation

```ruby
# Gemfile
gem 'money_attribute'
```

```sh
bundle install
bin/rails g money_attribute:initializer
```

The generator creates `config/initializers/money_attribute.rb`.

## Migration helpers

Two families of helpers — one per storage mode.

**Composite (amount + currency):**

| Method | Action |
|---|---|
| `add_money_attribute` / `t.money_attribute` | Amount column + currency column |
| `remove_money_attribute` / `t.remove_money_attribute` | Drops both columns |

**Single-column (fixed currency):**

| Method | Action |
|---|---|
| `add_money_amount` / `t.money_amount` | Amount column only (no currency) |
| `remove_money_amount` / `t.remove_money_amount` | Drops the column, same as `remove_colum` |

By default `t.money_attribute :price` creates a `decimal(20,4)` amount column and a `string` currency column. For single-column mode, `t.money_amount :price` creates just the decimal column.

Control the amount column type with `amount: { type: }` (composite) or the top-level `type:` shortcut (single-column):

| Amount type |Column type | `precision/scale` | Maximum | Integer digits |
|---|---|---|---|---|
| `:crypto_decimal` | `decimal` | `36/18`  | < 1 quintillion  | 18  |
| `:fiat_decimal`   | `decimal` | `20/4`   | < 10 quatrillion | 16  |
| `:fiat_integer`   | `bigint`  | stripped | < 922 trillion   | ~15 |

```ruby
class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.money_amount :price                            # decimal(20,4)
      t.money_amount :btc_balance, type: :crypto_decimal  # decimal(36,18)
      t.money_amount :qty,        type: :fiat_integer     # integer
      t.money_attribute :multi                         # decimal(20,4) + currency
      t.money_attribute :tax, amount: { type: :bigint }  # bigint + currency
      t.timestamps
    end
  end
end

class AddPriceToProducts < ActiveRecord::Migration[8.1]
  def change
    add_money_attribute :products, :price                 # add price + price_currency
    add_money_amount   :products, :fee, type: :fiat_integer
    remove_money_attribute :products, :obsolete_fee       # reversible in change
    remove_money_amount   :products, :old_fixed_fee
  end
end
```

### Naming

| Migration call | Columns created | Model declaration |
|---|---|---|
| `t.money_attribute :price` | `price` decimal + `price_currency` string | `money_attribute :price` |
| `t.money_attribute :price_amount` | `price_amount` decimal + `price_currency` string | `money_attribute :price` |
| `t.money_amount :price` | `price` decimal(20,4) | `money_amount :price` |
| `t.money_amount :btc, type: :crypto_decimal` | `btc` decimal(36,18) | `money_amount :btc` |
| `t.money_amount :price, type: :fiat_integer` | `price` integer | `money_amount :price` |
| `t.money_amount :price, type: :fiat_decimal` | `price` decimal(20,4) | `money_amount :price` |
| `t.money_attribute :price, amount: { type: :integer }` | `price` integer + `price_currency` string | `money_attribute :price` |
| `t.money_attribute :price, amount: { column: :a }, currency: { column: :c }` | `a` + `c` | `money_attribute :price, mapping: { amount: :a, currency: :c }` |
| `t.money_attribute :price, currency: { limit: 3 }` | `price` decimal(20,4) + `price_currency` string(3) | `money_attribute :price` |
| `t.money_attribute :price, amount: { precision: 14, scale: 2, null: false }, currency: { limit: 3, default: 'USD' }` | `price` decimal(14,2) NOT NULL + `price_currency` string(3) DEFAULT 'USD' | `money_attribute :price` |
| `t.remove_money_attribute :price` | Removes `price` + `price_currency` | `money_attribute :price` |

Inside `change_table`:

```ruby
change_table :products do |t|
  t.remove_money_attribute :obsolete_fee   # removes obsolete_fee + obsolete_fee_currency
end
```

## Configuration

```ruby
# config/initializers/money_attribute.rb
MoneyAttribute.configure do |config|
  config.default_currency = 'USD'
end
```

See the [Minting gem](https://github.com/gferraz/minting) for full configuration options (custom currencies, formatting, rounding).

### I18n / Locale-aware formatting

MoneyAttribute integrates with Rails I18n to automatically format money amounts according to the current locale.

With `I18n.locale` set to `:en`:
```ruby
Mint.money(1234.56, 'USD').to_s  # => "$1,234.56"
```

Switch to `:'pt-BR'` and the separators change automatically (requires [`rails-i18n`](https://github.com/svenfuchs/rails-i18n) or your own locale file):
```ruby
I18n.locale = :'pt-BR'
Mint.money(1234.56, 'USD').to_s  # => "$1.234,56"
```

The locale backend reads `number.currency.format` from your I18n translations and maps Rails format syntax (`%n` for amount, `%u` for unit) to `Mint::Money#to_s`. If the translation key is missing (no locale file for that language), it falls back to hardcoded defaults (`.` decimal, `,` thousand, `%<symbol>s%<amount>f` format).

You can configure per-sign formatting by adding `positive`, `negative`, and `zero` keys to your locale:

```yaml
# config/locales/money_attribute.en.yml
en:
  number:
    currency:
      format:
        format: "%u%n"           # fallback when no per-sign key matches
        positive: "%u%n"         # "$1,234.56"
        negative: "(%u%n)"       # "($1,234.56)"
        zero: "--"               # "--"
        separator: "."
        delimiter: ","
```

When any of `positive`, `negative`, or `zero` is present, a Hash format is built. Missing keys fall back to `format`:

```ruby
Mint.money(1234.56, 'USD').to_s  # => "$1,234.56"
Mint.money(-1234.56, 'USD').to_s # => "($1,234.56)"
Mint.money(0, 'USD').to_s        # => "--"
```

If none of those keys are set, `format` is used as a plain string (simple formatting).

> Formatting respects the currency's own `subunit` for decimal precision — `I18n` locale settings for `precision` are ignored since that is a currency property, not a locale one.

## Usage — two modes

### Decision table

| | Fixed currency (single column) | Multi-currency (amount + currency) |
|---|---|---|
| **Migration** | `t.money_amount :price` (or `t.decimal :price`) | `t.money_attribute :price` (or `t.decimal :price_amount` + `t.string :price_currency`) |
| **Model** | `money_amount :price, currency: 'USD'` | `money_attribute :price` |
| **When to use** | Column always holds the same currency | Each row can hold a different currency |
| **Column type** | `decimal`, `integer`, or `bigint` | `decimal`, `integer`, or `bigint` for amount; `string` for currency |
| **Query** | `Product.where(price: 10.to_money('USD'))` — full type support | `Offer.where(price: 10.to_money('EUR'))` — equality only |

### Fixed currency

```ruby
class Product < ApplicationRecord
  money_amount :price, currency: 'USD'
end

product = Product.new(price: 12)
product.price # => [USD 12.00]

Product.new(price: 12.to_money('EUR'))
# => ArgumentError: ... has different currency. Only USD allowed.
```

### Multi-currency

```ruby
class Offer < ApplicationRecord
  money_attribute :price
end

offer = Offer.new(price: 15.to_money('EUR'))
offer.price          # => [EUR 15.00]
offer.price_amount   # => 15.0
offer.price_currency # => "EUR"

offer = Offer.new(price: '12')
offer.price.currency.code # => "USD"
```

Unlike fixed-currency attributes, composite mode does not enforce a specific currency — any registered currency is accepted at assignment.

## Column type detection

Declare the column as `decimal`, `integer`, or `bigint` — the gem adapts:

```ruby
# Migration
create_table :orders do |t|
  t.money_attribute :total, amount: { type: :bigint }   # stored as cents (subunits)
end

# Model
class Order < ApplicationRecord
  money_attribute :total
end

Order.new(total: 19.99.to_money('USD')).total_amount # => 1999
```

For fixed-currency attributes, use `t.money_amount` with the `type:` shortcut:

```ruby
# Migration
t.money_amount :price, type: :fiat_integer  # integer column

# Model
money_amount :price, currency: 'USD'
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

The mapping keys are `:amount` and `:currency`; values are your database column names. You can provide only one key — the other falls back to the `<name>_amount` / `<name>_currency` convention:

```ruby
class Invoice < ApplicationRecord
  money_attribute :total, mapping: { amount: :total_amount }
  # currency column inferred as `total_currency`
end
```

## Column resolution

`money_attribute :name` is always composite. It resolves columns in this order:

| Step | Condition | Columns used |
|---|---|---|
| 1 | `mapping:` provided | As specified (missing keys fall back to `<name>_amount` / `<name>_currency`) |
| 2 | `name_currency` column exists AND `name` column exists | `name` + `name_currency` |
| 3 | `name == 'amount'` AND `currency` column exists | `amount` + `currency` |
| 4 | None of the above | `<name>_amount` + `<name>_currency` (convention) |

Step 4 raises `ArgumentError` if the convention columns don't exist. For single-column fixed-currency attributes, use `money_amount` instead.

**Example**

```ruby
create_table :financial_transactions do |t|
  t.integer :amount
  t.string  :currency, limit: 3
  t.integer :discount
  t.string  :discount_currency, limit: 3
  t.decimal :price_amount
  t.string  :price_currency, limit: 3
  t.bigint  :tax
  t.decimal :total_amount
  t.string  :currency_code, limit: 3
end
```

```ruby
class FinancialTransaction < ApplicationRecord
  money_attribute :amount                   # step 3: amount(int) + currency
  money_attribute :discount                 # step 2: discount(int) + discount_currency
  money_attribute :price                    # step 4: price_amount + price_currency
  money_attribute :total, mapping: { amount: :total_amount, currency: :currency_code }  # step 1: explicit
  money_amount  :tax                        # single-column, fixed-currency (uses default currency)
end
```

## Querying

Fixed-currency attributes support Rails-native querying through the custom type:

```ruby
# Equality
Product.where(price: 10.to_money('USD'))

# IN clause
Product.where(price: [10.to_money('USD'), 20.to_money('USD')])

# BETWEEN
Product.where(price: 10.to_money('USD')..20.to_money('USD'))

# Ordering
Product.order(price: :desc)

# Aggregation
Product.where(price: 10.to_money('USD')).sum(:price)
```

Multi-currency attributes support equality queries via `composed_of`:

```ruby
Offer.where(price: 10.to_money('EUR'))
```

For comparisons on multi-currency attributes, use the backing columns directly:

```ruby
Offer.where(price_amount: 10..20, price_currency: 'EUR')
Offer.where('price_amount > ? AND price_currency = ?', 10, 'EUR')
```

## Convenience methods

MoneyAttribute adds small helpers on `Numeric` and `String`:

```ruby
12.to_money('USD')    # => [USD 12.00]
12.dollars            # => [USD 12.00]
12.euros              # => [EUR 12.00]
```

> If you prefer not to extend core classes, use `Mint.money(12, 'USD')` instead.

## Form helpers

MoneyAttribute adds `money_field` and `money_amount_field` to Rails form builders. `money_field` renders a text input with the locale-formatted money string; `money_amount_field` renders a number input with the raw decimal value.

```erb
<%= form_with model: @product do |form| %>
  <%= form.label :price %>
  <%= form.money_field :price %>       <!-- text input, e.g. "$1,234.56" -->

  <%= form.label :tax %>
  <%= form.money_amount_field :tax %>  <!-- number input, e.g. "1234.56" -->
<% end %>
```

## Roadmap

1. **Method-level currency** — lambda-based currency resolution for multi-tenant and instance-level scenarios
2. Prepare for official 1.0 launch

Contributions and suggestions are welcome — open an issue or PR at [gferraz/money-attribute](https://github.com/gferraz/money-attribute).

## Development

```sh
bundle install
bundle exec rake test
```

The dummy Rails app under `test/dummy` exercises the engine in a full Rails environment.

## Contributing

Bug reports and pull requests welcome at [gferraz/money-attribute](https://github.com/gferraz/money-attribute).

## License

[MIT](MIT-LICENSE)
