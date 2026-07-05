# AGENTS.md — money-attribute

## Identity

Rebranded from `minting-rails` → `money_attribute`. All repo code uses `MoneyAttribute::` namespace; the `minting` gem remains a runtime dependency providing `::Mint::Money` and `::Mint::Currency`.

## Commands

```sh
bundle exec rake           # run tests only (default task, no migration)
bundle exec rake test      # migrate test DB + run tests
bundle exec rake test_run  # run tests only (same as default)
bundle exec rake test_db_migrate  # migrate test DB only
bundle exec rake bench     # money_attribute vs money-rails benchmark
bundle exec rubocop        # lint (commented out in CI, but run manually)
```

Single test: `bundle exec ruby -Itest test/money_attribute/money_attribute_test.rb`

## Tests

- **Framework:** Minitest via `ActiveSupport::TestCase` (no RSpec), fixtures loaded automatically
- Dummy Rails app at `test/dummy/` — migrate before running (`rake test` does this); SQLite3 DB at `test/dummy/storage/test.sqlite3`
- **7** test files in `test/money_attribute/`
- **98** tests, all passing
- Dummy app initializer sets `default_currency = 'BRL'` — test expectations assume BRL, not USD
- Config-mutating tests: use `with_money_attribute_config` (in `rails_test.rb:215`), which saves/restores config and re-registers currencies
- RuboCop enforces `Minitest/MultipleAssertions: max 4` — warns on 5+ assertions
- `-rtest_helper.rb` is baked into Rakefile via `t.ruby_opts`

## Gotchas

1. **AR type key is `:mint_money`, not `:money`.** Despite the rebrand plan (`REBRAND.md` listed `:money`), `type.rb:59` and `macro.rb:83` still use the old key.
2. **Converter plays two roles.** `MoneyAttribute::Converter` is passed as `:converter` to `composed_of` (composite path) and as the normalizer block to `normalizes` (single-column path).
3. **Schema has mixed column types.** `financial_transactions.amount` is integer (subunits), `price_amount`/`total_amount` are decimal (unit value). Query expectations differ.
4. **Form builder helpers render unbound `<input>` tags** (not form-builder-bound fields). `money_field` → text with `to_fs(:currency)`; `money_amount_field` → number with raw decimal.

## Architecture

- **Entry point:** `lib/money_attribute.rb` requires all components in dependency order
- **Two explicit helpers** (no auto-detect — the method name declares the mode):
  1. `money_amount :price, currency: 'USD'` — **single-column fixed-currency.** Stores amount in one column (`price`). Uses `ActiveRecord::Type` subclass `MoneyAttribute::Type` (registered as `:mint_money`) + `normalizes`. Currency never changes per row.
  2. `money_attribute :price` — **composite amount+currency.** Two DB columns (`price_amount` + `price_currency` or custom via `mapping:`). Per-row currency via `composed_of` + `Converter`. Integer/bigint → subunits, decimal → unit value.
- **Column resolution** for `money_attribute` (composite only, checked after `mapping:`):
  1. `name_currency` column exists AND `name` column exists → composite (`name` + `name_currency`)
  2. `name == 'amount'` AND `currency` column exists → composite (`amount` + `currency`)
  3. Otherwise → convention (`name_amount` + `name_currency`); raises `ArgumentError` if missing
- Using `money_attribute` when only a single column exists raises with a hint to use `money_amount`
- Custom currency registration: `MoneyAttribute::Railtie.register_custom_currencies!`

## Migration helpers

Two separate helpers — one per storage mode:

| Helper | Columns created |
|---|---|
| `add_money_attribute` / `t.money_attribute` | Amount column + currency column (composite) |
| `add_money_amount` / `t.money_amount` | Amount column only (single-column) |

`money_attribute` naming conventions:

| Accessor | Amount column | Currency column | Notes |
|---|---|---|---|
| `:price` | `price` | `price_currency` | Default |
| `:price_amount` | `price_amount` | `price_currency` | Strips `_amount` suffix |
| `:amount` | `amount` | `currency` | Special case |
| `:price, amount: { column: :a }, currency: { column: :c }` | `a` | `c` | Explicit mapping |

`money_amount` naming: column name = accessor (no currency column).

- Default amount type: `:decimal` precision 20, scale 4 (fiat); `type: :crypto_decimal` → `decimal(36,18)`; `type: :fiat_integer` → `bigint`
- `:integer`/`:bigint` types strip precision/scale
- Methods are reversible inside `change`

## Style

- RuboCop with minitest, performance, packaging, rake, rails, thread_safety plugins
- `Layout/LineLength: 120`, `Metrics/MethodLength: 30`, `Style/FrozenStringLiteralComment: always`
- `test/dummy/` excluded from RuboCop
- All source files have `# frozen_string_literal: true`
- RuboCop is commented out in CI workflow — run manually

## Dependencies

- Ruby >= 3.3 (`.tool-versions`: 4.0.5), Rails >= 7.1.3.2, minting >= 1.9.0
- CI tests Ruby 3.3, 3.4, 4.0 (GitHub Actions, `bundler-cache: true`)
