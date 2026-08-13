# AGENTS.md — money-attribute

## Identity

Rebranded from `minting-rails` → `money_attribute`. All repo code uses `MoneyAttribute::` namespace; the `minting` gem remains a runtime dependency providing `::Mint::Money` and `::Money::Currency`.

## Commands

```sh
bundle exec rake           # run tests only (default task, no migration)
bundle exec rake test      # migrate test DB + run tests
bundle exec rake test_run  # run tests only (same as default)
bundle exec rake test_db_migrate  # migrate test DB only
bundle exec rake test:all  # sqlite3 + postgresql + mysql2 (pg/mysql need local services; see DATABASE_ADAPTER)
bundle exec rake test:postgresql  # migrate + run against postgresql
bundle exec rake test:mysql2      # migrate + run against mysql2
bundle exec rake bench     # 3-sided benchmark: money_attribute vs plain Rails vs money-rails (money-rails side uses Gemfile.benchmark to avoid gem conflict)
bundle exec rake bench:report  # generate consolidated markdown report from benchmark output
bundle exec rake bench:profile MODE=string_query  # stackprof profiling (modes: string_query|pluck|read_cached|multi_record|arithmetic|all)
bundle exec rubocop        # lint (runs in CI; 0 offenses as of 1.2.1)
```

Single test: `bundle exec ruby -Itest test/money_attribute/money_attribute_test.rb`

## Benchmark

Run via `rake bench` (depends on `test_db_migrate`) — spawns three processes (one per gem stack) to avoid gem conflicts. Dispatcher is `benchmark/comparison.rb`, side files `benchmark/{minting,plain,money_rails}.rb`:

1. `BENCH_SIDE=minting` — uses money_attribute + minting gems
2. `BENCH_SIDE=plain` — plain ActiveRecord (raw columns, no monetization)
3. `BENCH_SIDE=money_rails BUNDLE_GEMFILE=Gemfile.benchmark` — uses money-rails + money gems

All sides use the same minimal environment: `require 'rails'`, `require 'active_record'`, direct SQLite connection to `test/dummy/storage/test.sqlite3` (no full Rails app boot). Fair comparison.

- Query sections use **raw column values** on all sides — money-rails cannot decompose `Money` objects in `find_by`. Section 5 (money_attribute only) separately benchmarks composed_of decomposition of `Mint::Money` objects.
- Money-object queries via composed_of decomposition work in money_attribute (money-rails cannot decompose `Money` in WHERE clauses).
- Full result tables live in `BENCHMARKS.md` and `benchmark/reports/` — regenerate via `rake bench:report`, don't hand-edit. `rake bench:profile MODE=...` uses stackprof (`benchmark/profile.rb`).

## Tests

- **Framework:** Minitest via `ActiveSupport::TestCase` (no RSpec), fixtures loaded automatically
- Dummy Rails app at `test/dummy/` — migrate before running (`rake test` does this); SQLite3 DB at `test/dummy/storage/test.sqlite3`
- **20** test files in `test/money_attribute/`
- **297** tests, **596** assertions, all passing
- Dummy app initializer sets `default_currency = 'BRL'` — test expectations assume BRL, not USD
- Config-mutating tests: use `with_money_attribute_config` (in `rails_test.rb:229`), which saves/restores config and re-registers currencies
- RuboCop enforces `Minitest/MultipleAssertions: max 4` — warns on 5+ assertions; runs in CI
- `-rtest_helper.rb` is baked into Rakefile via `t.ruby_opts`

## Reference docs

- Deep-dive docs live in `doc/` (`MONEY_AMOUNT.md`, `QUERY_HELPERS.md`) — read them before touching those subsystems.
- `doc/agents/AGENTS.md` is a **stale pre-rebrand file** (minting-rails era, wrong test paths) — ignore it; this file is canonical.

## Gotchas

1. **No AR type key registered.** `money_amount` passes a `MoneyAttribute::Type` instance directly to `attribute()` — no global `:mint_money` registration. The old `:money` key was dropped during rebranding due to PostgreSQL adapter conflicts.
2. **Converter plays two roles.** `MoneyAttribute::Converter` is passed as `:converter` to `composed_of` (composite path) and as the normalizer block to `normalizes` (single-column path).
3. **Schema has mixed column types.** `financial_transactions.amount` is integer (subunits), `price_amount`/`total_amount` are decimal (unit value). Query expectations differ.
4. **Form builder helpers render unbound `<input>` tags** (not form-builder-bound fields). `money_field` → text with `to_fs`; `money_amount_field` → number with raw decimal.

## Architecture

- **Entry point:** `lib/money_attribute.rb` requires all components in dependency order
- **Per-request currency:** `MoneyAttribute::Current` (ActiveSupport::CurrentAttributes). Set `Current.currency` in `before_action`; Rails' Executor auto-resets after request. Falls back to `config.default_currency`.
- **Configuration:** Plain `Config` class with `Mutex` for thread safety. No `ActiveSupport::Configurable` (deprecated Rails 8.1, removed 8.2).
- **Two explicit helpers** (no auto-detect — the method name declares the mode):
  1. `money_amount :price` — **single-column fixed-currency.** Stores amount in one column (`price`). Uses application default currency. Uses `ActiveRecord::Type` subclass `MoneyAttribute::Type` + `normalizes`. Currency never changes per row.
  2. `money_attribute :price` — **composite amount+currency.** Two DB columns (`price_amount` + `price_currency` or custom via `mapping:`). Per-row currency via `composed_of` + `Converter`. Integer/bigint → subunits, decimal → unit value.
- **Attribute spec registry** is keyed by model class, then attribute name. Same attribute names do not conflict across models, but subclass/STI inheritance does not automatically copy a parent model's registry entries. Re-register money attributes in subclasses if needed.
- **Column resolution** for `money_attribute` (composite only, checked after `mapping:`):
  1. `name_currency` column exists AND `name` column exists → composite (`name` + `name_currency`)
  2. `name == 'amount'` AND `currency` column exists → composite (`amount` + `currency`)
  3. Otherwise → convention (`name_amount` + `name_currency`); raises `ArgumentError` if missing
- Using `money_attribute` when only a single column exists raises with a hint to use `money_amount`
- `money_attribute` never uses `type:` top-level option — use `amount: { type: }` instead
- Custom currency registration: `MoneyAttribute::Railtie.register_custom_currencies!`
- **Query helpers:** `MoneyAttribute::Query` module, included in `ActiveRecord::Base` (class methods) and `ActiveRecord::Relation` (scope methods). Provides `where_currency`, `where_amount`, `order_by_amount`, `pluck_amount`, `pick_amount`, and `sum_amount`. `where_amount` accepts a hash (keyword syntax) or a SQL string with `?` placeholders (only the attribute name, `and`, `or`, `not`, `is`, `null` allowed as identifiers). `pluck_amount` and `pick_amount` follow Rails arity: one attribute returns a single-column result, multiple attributes return row arrays. Composite attributes decompose to backing columns; single-column delegates to native AR. `sum_amount` accepts attribute names only (no currency parameter); composite attributes use SQL `GROUP BY` on the currency column, returning `Hash{String => Mint::Money}` when multiple currencies exist, single `Mint::Money` when one. Single-column attributes always return `Mint::Money`. Query logic split across `query/*.rb` sub-modules.

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

`money_amount` naming: column name = accessor (no currency column, no custom mapping).

- Amount column type selected via `type:` option — three values:
  - `:fiat_decimal` (default) → `decimal(20,4)` — up to ~10 quadrillion units
  - `:crypto_decimal` → `decimal(36,18)` — up to ~1 quintillion units
  - `:fiat_integer` → `bigint` — up to ~922 trillion units (subunits)
- Config-driven via `AMOUNT_CONFIG` hash in `helper.rb`; raw Rails types (`:decimal`, `:bigint`) not accepted directly
- `:fiat_integer` maps to `bigint`, not `integer`, matching `decimal(20,4)` capacity
- Precision/scale overrides intentionally dropped — error-prone for crypto
- Currency column default limit 16, range `4..32`, enforced via `clamp`
- `parse_money_amount_args` is the shared entry point for both migration helpers
- Methods are reversible inside `change`

## Style

- RuboCop with minitest, performance, packaging, rake, rails, thread_safety plugins; `NewCops: enable`
- `Layout/LineLength: 120`, `Metrics/MethodLength: 30`, `Metrics/ClassLength: 500`, `Style/FrozenStringLiteralComment: always`
- `test/dummy/`, `benchmark/`, `vendor/` excluded from RuboCop
- All source files have `# frozen_string_literal: true`
- RuboCop runs in CI; 0 offenses as of 1.2.1

## Dependencies

- Ruby >= 3.3 (`.tool-versions`: 4.0.6), Rails >= 7.1 (gemspec), minting >= 2.1 (gemspec)
- CI runs 3 jobs: sqlite3 on Ruby 3.3/3.4/4.0 (includes RuboCop), plus postgresql and mysql2 jobs on Ruby 3.4 (each spins up a service container)
