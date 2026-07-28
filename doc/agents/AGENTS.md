# AGENTS.md — minting-rails

## Commands

```sh
bundle exec rake test         # migrate test DB + run tests (default task)
bundle exec rake test_run     # run tests only (skip migration)
bundle exec rake test_db_migrate  # migrate test DB only
bundle exec rake bench        # minting-rails vs money-rails benchmark
bundle exec rubocop           # lint (commented out in CI, but run manually)
```

Single test: `bundle exec ruby -Itest test/minting/money_attribute_test.rb`

## Test details

- **Framework:** Minitest via `ActiveSupport::TestCase` (no RSpec, no fixtures)
- Dummy Rails app at `test/dummy/` — **always migrate before running** (`rake test` does this)
- SQLite3 test DB at `test/dummy/storage/test.sqlite3`
- 5 test files in `test/minting/` testing fixed-currency, multi-currency, integer column, I18n, and config

## Architecture

- **Entry point:** `lib/minting/rails.rb` requires all components
- **Column resolution** (checked in order):
  1. Explicit `mapping:` → as specified
  2. `name_currency` exists → composite (`name` + `name_currency`)
  3. `name == 'amount'` AND `currency` exists → composite (`amount` + `currency`)
  4. `name_amount` + `name_currency` exist → composite (convention)
  5. `name` column exists → single-column fixed-currency (`MintMoneyType`)
- Column type auto-detection: `integer`/`bigint` stores fractional (cents), `decimal` stores unit value
- Custom currency registration via `Mint::Railtie.register_custom_currencies!`
- I18n locale backend reads `number.currency.format` from Rails translations

## Ruby & Rails

- Ruby 4.0.5 (`.tool-versions`), Rails 8.1.3
- Min dependency: `minting >= 1.8.1`, `rails >= 7.1.3.2`
- CI tests Ruby 3.3, 3.4, 4.0 (GitHub Actions, `bundler-cache: true`)

## Generator

- `rails g mint:initializer` creates `config/initializers/minting.rb`

## Style

- RuboCop with minitest, performance, packaging, rake, rails, thread_safety plugins
- `Layout/LineLength: 100`, `Metrics/MethodLength: 30`
- `Style/FrozenStringLiteralComment: always`
- `test/dummy/` excluded from RuboCop
