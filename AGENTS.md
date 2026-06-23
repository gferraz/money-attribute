# AGENTS.md — money-attribute

## Identity

This gem was **rebranded from `minting-rails` → `money_attribute`**. See `REBRAND.md` for the full rename map. Old references to `Mint::`, `minting/`, `test/minting/` are stale — the current namespace is `MoneyAttribute::`, paths are `money_attribute/`.

## Commands

```sh
bundle exec rake test         # migrate test DB + run tests (default task)
bundle exec rake test_run     # run tests only (skip migration)
bundle exec rake test_db_migrate  # migrate test DB only
bundle exec rake bench        # money_attribute vs money-rails benchmark
bundle exec rubocop           # lint (commented out in CI, but run manually)
```

Single test: `bundle exec ruby -Itest test/money_attribute/money_attribute_test.rb`

## Test details

- **Framework:** Minitest via `ActiveSupport::TestCase` (no RSpec, fixtures loaded)
- Dummy Rails app at `test/dummy/` — **always migrate before running** (`rake test` does this)
- SQLite3 test DB at `test/dummy/storage/test.sqlite3`
- 6 test files in `test/money_attribute/` covering single-column, composite, migration helpers, I18n, config, and the financial_transaction integration example
- `test/dummy/db/schema.rb` has the full test schema

## Architecture

- **Entry point:** `lib/money_attribute.rb` requires all components; registers `MoneyAttribute::Macro` on `ActiveSupport.on_load(:active_record)` in `type.rb`
- **Two storage modes:** single-column fixed-currency (via `ActiveRecord::Type` subclass `MoneyAttribute::Type`, registered as `:money`) vs composite amount+currency (via `composed_of` + `MoneyAttribute::Parser`)
- **Column resolution** (checked in order within `Macro#resolve_mapping`):
  1. Explicit `mapping:` → as specified
  2. `name_currency` exists → composite (`name` + `name_currency`)
  3. `name == 'amount'` AND `currency` exists → composite (`amount` + `currency`)
  4. No match → fallback to single-column fixed-currency
- Column type auto-detection: `integer`/`bigint` stores subunits (cents), `decimal` stores unit value
- Custom currency registration via `MoneyAttribute::Railtie.register_custom_currencies!`
- I18n locale backend reads `number.currency.format` from Rails translations
- Core extensions (`Numeric#to_money`, `String#to_money`, `#dollars`, `#euros`) in `lib/money_attribute/core_ext.rb`

## Dependencies

- Ruby >= 3.3 (`.tool-versions`: 4.0.5), Rails >= 7.1.3.2, minting >= 1.9.0
- CI tests Ruby 3.3, 3.4, 4.0 (GitHub Actions, `bundler-cache: true`)

## Generator

- `rails g money_attribute:initializer` creates `config/initializers/money_attribute.rb`

## Style

- RuboCop with minitest, performance, packaging, rake, rails, thread_safety plugins
- `Layout/LineLength: 120`, `Metrics/MethodLength: 30`, `Style/FrozenStringLiteralComment: always`
- `test/dummy/` excluded from RuboCop

## Previous agent work

- `doc/agents/AGENTS.md` — stale, superseded by this file
- `doc/agents/review-2026-06-12.md` — prior code review; findings are already incorporated
