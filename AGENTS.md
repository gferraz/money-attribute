# AGENTS.md — money-attribute

## Identity

Rebranded from `minting-rails` → `money_attribute`. All repo code uses `MoneyAttribute::` namespace; the `minting` gem remains a runtime dependency providing `::Mint::Money` and `::Money::Currency`.

## Commands

```sh
bundle exec rake           # run tests only (default task, no migration)
bundle exec rake test      # migrate test DB + run tests
bundle exec rake test_run  # run tests only (same as default)
bundle exec rake test_db_migrate  # migrate test DB only
bundle exec rake bench     # 3-sided benchmark: money_attribute vs plain Rails vs money-rails (money-rails side uses Gemfile.benchmark to avoid gem conflict)
bundle exec rake bench:report  # generate consolidated markdown report from benchmark output
bundle exec rubocop        # lint (runs in CI; 0 offenses as of 1.1.0)
```

Single test: `bundle exec ruby -Itest test/money_attribute/money_attribute_test.rb`

## Benchmark

Run via `rake bench` — spawns three processes (one per gem stack) to avoid gem conflicts:

1. `BENCH_SIDE=minting` — uses money_attribute + minting gems
2. `BENCH_SIDE=plain` — plain ActiveRecord (raw columns, no monetization)
3. `BENCH_SIDE=money_rails BUNDLE_GEMFILE=Gemfile.benchmark` — uses money-rails + money gems

All sides use the same minimal environment: `require 'rails'`, `require 'active_record'`, direct SQLite connection to `test/dummy/storage/test.sqlite3` (no full Rails app boot). Fair comparison.

Query sections use **raw column values** on all sides — money-rails cannot decompose `Money` objects in `find_by`. Section 5 (money_attribute only) separately benchmarks composed_of decomposition of `Mint::Money` objects.

Key findings (integer column, 5000 iters unless noted):

| Test | money_attribute | plain Rails | money-rails | ma / plain |
|---|---|---|---|---|
| Instantiation | 0.042s | 0.033s | 0.043s | **1.3×** |
| Create+save | 0.690s | 0.693s | 1.061s | **1.0×** (write-dominated) |
| Update existing (2 values) | 0.673s | 0.685s | 0.997s | **1.0×** (write-dominated) |
| Setter only | 0.010s | 0.002s | 0.016s | **5.3×** (conversion cost) |
| Read cached | 0.0005s | 0.0008s | 0.016s | **0.6×** (caching wins) |
| Query raw columns | 0.197s | 0.184s | 0.199s | **1.1×** |
| SQL generation | 0.190s | 0.183s | 0.197s | **1.0×** |
| Multi-record (100×1000) | 0.584s | 0.287s | 0.842s | **2.0×** (composed_of overhead on 100K reads) |
| Repeated access | 0.0004s | 0.0008s | 0.018s | **0.6×** (caching wins) |
| Allocations (×5000) | 2 | 2 | 75,002 | — |

**Query helpers (5000 iters, 100 records):**

| Benchmark | money_attribute | plain Rails | ma / plain |
|---|---|---|---|
| `where_amount` (hash scalar) | 0.027s | 0.074s | **0.4×** |
| `where_amount` (hash Range) | 0.034s | 0.100s | **0.3×** |
| `where_amount` (hash Array) | 0.035s | 0.057s | **0.6×** |
| `where_amount` (String `<`) | 0.060s | 0.017s | **3.6×** |
| `where_amount` (String AND) | 0.080s | 0.018s | **4.4×** |
| `where_amount` (String NOT) | 0.063s | 0.018s | **3.5×** |
| `where_amount` (String IS NULL) | 0.055s | 0.017s | **3.2×** |
| `where_currency` | 0.042s | 0.040s | **1.1×** |
| `order_by_amount` (desc) | 1.263s | 1.155s | **1.1×** |
| `pluck_amount` single | 1.044s | 0.291s | **3.6×** |
| `pick_amount` single | 0.257s | 0.205s | **1.3×** |
| `sum_amount` | 0.449s | 0.429s | **1.0×** |

money_attribute's hash-form queries are 1.6-3× **faster** than raw `where` (decomposition via composed_of is cheap, and raw hash construction is slower). String-form queries are 3-4× slower due to SQL parsing + attribute substitution. `pluck_amount` is 3.6× slower because it composes Money objects from raw pluck values.

**Scaling (mass insert and bulk update)**

Ratio stays constant across all batch sizes — overhead is purely per-record, not per-batch.

**Mass insert (records × 1 transaction):**

| Size | money_attribute int | money_attribute dec | money-rails | ratio |
|---|---|---|---|---|
| 100 | 0.008s | 0.009s | 0.015s | **0.5×** |
| 500 | 0.041s | 0.042s | 0.070s | **0.6×** |
| 1000 | 0.090s | 0.081s | 0.151s | **0.6×** |
| 2000 | 0.158s | 0.180s | 0.286s | **0.6×** |

**Bulk update (Model.update, N records, alternating values):**

| Size | money_attribute int | money_attribute dec | money-rails | ratio |
|---|---|---|---|---|
| 100 | 0.013s | 0.015s | 0.020s | **0.7×** |
| 500 | 0.066s | 0.072s | 0.098s | **0.7×** |
| 1000 | 0.151s | 0.147s | 0.201s | **0.8×** |
| 2000 | 0.290s | 0.310s | 0.428s | **0.7×** |

money_attribute's main advantages: **zero-allocation caching** (0.6× ma/plain ratio — faster than plain Rails), **1.7× faster inserts**, **1.4× faster bulk updates**, support for **Money-object queries** via composed_of decomposition (money-rails cannot decompose `Money` in WHERE clauses).

## Tests

- **Framework:** Minitest via `ActiveSupport::TestCase` (no RSpec), fixtures loaded automatically
- Dummy Rails app at `test/dummy/` — migrate before running (`rake test` does this); SQLite3 DB at `test/dummy/storage/test.sqlite3`
- **20** test files in `test/money_attribute/`
- **297** tests, **596** assertions, all passing
- Dummy app initializer sets `default_currency = 'BRL'` — test expectations assume BRL, not USD
- Config-mutating tests: use `with_money_attribute_config` (in `rails_test.rb:215`), which saves/restores config and re-registers currencies
- RuboCop enforces `Minitest/MultipleAssertions: max 4` — warns on 5+ assertions; runs in CI
- `-rtest_helper.rb` is baked into Rakefile via `t.ruby_opts`

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

- RuboCop with minitest, performance, packaging, rake, rails, thread_safety plugins
- `Layout/LineLength: 120`, `Metrics/MethodLength: 30`, `Style/FrozenStringLiteralComment: always`
- `test/dummy/` and `benchmark/` excluded from RuboCop
- All source files have `# frozen_string_literal: true`
- RuboCop runs in CI; 0 offenses as of 1.2.0

## Dependencies

- Ruby >= 3.3 (`.tool-versions`: 4.0.5), Rails >= 7.1.3.2, minting >= 2.0.0
- CI tests Ruby 3.3, 3.4, 4.0 (GitHub Actions, `bundler-cache: true`; RuboCop runs in CI)
