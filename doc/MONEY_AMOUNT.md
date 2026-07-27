# `money_amount` — Single-Column, Fixed-Currency Macro

Single-column macro. One DB column stores the amount; currency is always the
application default (or per-request via `Current.currency`).

## Declaration

```ruby
class SimpleOffer < ApplicationRecord
  money_amount :price           # decimal(20,4) by default
  money_amount :tax             # bigint if column is integer -> stores subunits
end
```

## How it works

Three things happen at class load time:

1. **`attribute(name, Type.new(...))`** -- registers a custom AR type that
   handles serialize/deserialize. Detects if the DB column is integer (subunits)
   or decimal (unit value).

2. **`normalizes(name, with: Converter.default)`** -- normalizes input
   (String/Numeric/Money/nil -> `Mint::Money`) on every assignment.

3. **`register_money_attribute_spec`** -- stores metadata (`kind: :single`) so
   query helpers know this is a single-column attribute.

## Serialize / Deserialize

| Direction | Integer column (`bigint`) | Decimal column (`decimal(20,4)`) |
|---|---|---|
| **Write** (serialize) | `money.subunits` -> Integer | `money.to_d` -> BigDecimal |
| **Read** (deserialize) | `Money.from_subunits(val, currency)` | `Money.from(val, currency)` |

Currency always comes from `MoneyAttribute.default_currency` (per-request ->
config fallback).

## Input normalization

`Converter.default` handles all assignment paths:

- `Mint::Money` -- passthrough
- `Numeric` -- `Money.from(amount, currency)`
- `String` -- `Money.parse(amount, currency)`
- `nil` -- passthrough

`Type#assert_valid_value` raises if a `Money` object has a currency different
from the fixed default.

## Migration

```ruby
# create_table
t.money_amount :tax, type: :fiat_integer   # -> bigint

# alter table
add_money_amount :offers, :tax, type: :fiat_decimal  # -> decimal(20,4)
```

Three predefined types only: `:fiat_decimal` (default, `decimal(20,4)`),
`:crypto_decimal` (`decimal(36,18)`), `:fiat_integer` (`bigint`). Custom
precision/scale intentionally rejected.

## Query helpers -- single-column behavior

| Helper | Behavior |
|---|---|
| `where_amount` | Works normally, queries the amount column |
| `where_currency` | **Raises** -- no currency column |
| `order_by_amount` | Orders by amount column only |
| `pluck_amount` | Returns `Array<Mint::Money>` (via `Type#deserialize`) |
| `pick_amount` | Returns `Mint::Money` or `nil` (via `Type#deserialize`) |
| `sum_amount` | Sums directly, wraps with default currency |

## Key difference from composite `money_attribute`

`money_amount` uses `attribute()` + `normalizes` (custom AR Type).
`money_attribute` uses `composed_of` (AR aggregations). They share the same
`Converter` and `AttributeSpec` but differ in everything else -- storage,
serialization, queries, migration helpers, and form helpers.

| Aspect | `money_amount` (single-column) | `money_attribute` (composite) |
|---|---|---|
| **DB columns** | 1 (amount only) | 2 (amount + currency) |
| **Currency storage** | None -- always the app default | Per-row in a separate `_currency` column |
| **AR integration** | `attribute()` + `Type` + `normalizes` | `composed_of` with constructor + converter |
| **Spec kind** | `:single` | `:composite` |
| **Migration helper** | `add_money_amount` / `t.money_amount` -- 1 column | `add_money_attribute` / `t.money_attribute` -- 2 columns |
| **Form helper** | `money_amount_field` -- `<input type="number">` | `money_field` -- `<input type="text">` |
| **Query: `where_currency`** | Raises -- no currency column | Filters by currency column |
| **Query: `pluck_amount`** | Returns `Array<Mint::Money>` | Returns `Array<Mint::Money>` |
| **Query: `sum_amount`** | Sums directly, wraps with default currency | Groups by currency column |
| **Per-request currency** | Works via `Current.currency` | Works via `Current.currency` |
