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
- **Two storage modes:**
  1. **Single-column fixed-currency:** `ActiveRecord::Type` subclass `MoneyAttribute::Type`, registered as `:mint_money`. Uses `attribute(name, :mint_money, ...)` + `normalizes(name, with: Converter.new(currency))`.
  2. **Composite amount+currency:** `composed_of` + `MoneyAttribute::Converter`. Two DB columns, per-row currency. Integer/bigint → subunits, decimal → unit value.
- **Column resolution** (in `Macro#resolve_mapping`, checked after explicit `mapping:`):
  1. `name_currency` column exists → composite (`name` + `name_currency`)
  2. `name == 'amount'` AND `currency` column exists → composite (`amount` + `currency`)
  3. Column exists but no `*_currency` → single-column fixed-currency
  4. Column does NOT exist → convention path; raises `ArgumentError` if columns missing
- Custom currency registration: `MoneyAttribute::Railtie.register_custom_currencies!`

## Migration helpers

`add_money_attribute` / `t.money_attribute` naming conventions:

| Accessor | Amount column | Currency column | Notes |
|---|---|---|---|
| `:price` | `price` | `price_currency` | Default |
| `:price_amount` | `price_amount` | `price_currency` | Strips `_amount` suffix |
| `:amount` | `amount` | `currency` | Special case |
| `:price, currency: false` | `price` | (none) | Single-column |

- Default amount type: `:decimal` precision 16, scale 4
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
