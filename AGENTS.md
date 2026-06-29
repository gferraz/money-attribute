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
- **Dummy app initializer** (`test/dummy/config/initializers/money_attribute.rb`) sets `default_currency = 'BRL'` — this affects all test expectations that reference `MoneyAttribute.default_currency`
- **Test helper pattern:** `with_money_attribute_config` in `rails_test.rb` saves/restores config and re-registers currencies — use this when writing tests that mutate config
- `Minitest/MultipleAssertions` max is 4 (RuboCop may warn on tests with 5+ assertions)
- Running with `-rtest_helper.rb` is baked into the Rakefile (`t.ruby_opts`)

## Architecture

- **Entry point:** `lib/money_attribute.rb` — requires all components in dependency order
- **Two storage modes:**
  1. **Single-column fixed-currency:** Uses `ActiveRecord::Type` subclass `MoneyAttribute::Type`, registered as `:mint_money`. A single DB column stores the amount; currency is fixed at declaration time. Uses `attribute(name, :mint_money, ...)` + `normalizes(name, with: Converter.new(currency))`.
  2. **Composite amount+currency:** Uses `composed_of` + `MoneyAttribute::Converter`. Two DB columns (amount + currency). Allows per-row currency. Supports integer/bigint (stores subunits) or decimal columns.
- **Column resolution** (checked in order within `Macro#resolve_mapping`):
  1. Explicit `mapping:` → as specified
  2. `name_currency` column exists → composite (`name` + `name_currency`)
  3. `name == 'amount'` AND `currency` column exists → composite (`amount` + `currency`)
  4. Column exists but no `*_currency` found → **single-column fixed-currency** (mapping stays nil)
  5. Column does NOT exist → composite path; `resolve_composite_for` will raise `ArgumentError` if mapped columns are missing
- Column type auto-detection: `integer`/`bigint` stores subunits (cents), `decimal` stores unit value
- Custom currency registration via `MoneyAttribute::Railtie.register_custom_currencies!`
- I18n locale backend reads `number.currency.format` from Rails translations
- Core extensions (`Numeric#to_money`, `String#to_money`, `#dollars`, `#euros`) in `lib/money_attribute/core_ext.rb`

## Migration helpers

The migration extensions (`add_money_attribute`, `t.money_attribute`) use `parse_money_args` in `helper.rb` with complex naming conventions:

| Accessor | Amount column | Currency column | Condition |
|---|---|---|---|
| `:price` | `price` | `price_currency` | Default convention |
| `:price_amount` | `price_amount` | `price_currency` | Strips `_amount` suffix from accessor |
| `:amount` | `amount` | `currency` | Special case when accessor is exactly `amount` |
| `:price, currency: false` | `price` | (none) | Single-column, no currency column |
| `:price, amount: { type: :integer }` | `price` (int) | `price_currency` | Integer amount column |
| `:price, amount: { column: :foo }` | `foo` | `price_currency` | Explicit amount column name |
| `:price, currency: { column: :c }` | `price` | `c` | Explicit currency column name |

- Default amount type is `:decimal` with precision 16, scale 4
- Non-decimal types (`:integer`, `:bigint`) strip precision/scale options
- Migration methods (`add_money_attribute`, `remove_money_attribute`) are reversible when called inside `change`

## Form builder

- `money_field(method, options)` — text input with `to_fs(:currency)` formatted value (for composite attributes)
- `money_amount_field(method, options)` — number input with raw decimal value (for single-column attributes)
- Extension is included on `ActionView::Helpers::FormBuilder` during `after_initialize`

## Gotchas & non-obvious patterns

1. **AR type key is `:mint_money`, not `:money`.** Despite the rebrand, the registered `ActiveRecord::Type` key is still `:mint_money` (defined in `MoneyAttribute::Type.type` and `type.rb:59`). The REBRAND.md listed `:money` as the intended new key, but it was never changed. Macro uses `attribute(name, :mint_money, ...)`.
2. **`remove_method :to_money` on core_ext.** `Numeric#to_money` and `String#to_money` call `remove_method` before defining to suppress Ruby redefinition warnings. Only affects classes that already define `to_money` (like `minting` gem).
3. **Converter is used as both constructor and normalizer.** `MoneyAttribute::Converter` is passed as the `:converter` option to `composed_of` and as the normalizer block to `normalizes` in the single-column path. It handles `Mint::Money` (pass-through), `Numeric`, `String`, and `nil`.
4. **Class-level instance variables in Configuration** (`@config`, `@default_currency`) are documented as safe because they're written during Rails boot (single-threaded) and read-only during request handling. RuboCop's `ThreadSafety/ClassInstanceVariable` warns about them.
5. **Test initializer sets BRL.** The dummy app's initializer sets `config.default_currency = 'BRL'`. The generator template uses `XCRC`/`XNGN` as example custom currencies. Tests that check `MoneyAttribute.default_currency` expect `BRL`, not `USD`.
6. **`assert_select` in integration tests.** Form builder tests use `ActionDispatch::IntegrationTest` with `assert_select` for HTML assertions — the `money_field` renders raw `<input>` tags (not form builder bound fields), so assertions use generic CSS selectors.
7. **Schema uses both integer and decimal columns.** The `financial_transactions` table has `amount` (integer → subunits) and `price_amount`/`total_amount` (decimal → unit value). Query expectations differ based on column type.

## Dependencies

- Ruby >= 3.3 (`.tool-versions`: 4.0.5), Rails >= 7.1.3.2, minting >= 1.9.0
- CI tests Ruby 3.3, 3.4, 4.0 (GitHub Actions, `bundler-cache: true`)
- **RuboCop is commented out in CI** (`# - run: bundle exec rubocop`) — run manually

## Generator

- `rails g money_attribute:initializer` copies `lib/generators/templates/money_attribute.rb` → `config/initializers/money_attribute.rb`
- Template uses `XCRC`/`XNGN` as example custom currencies and `BRL` as example default

## Style

- RuboCop with minitest, performance, packaging, rake, rails, thread_safety plugins
- `Layout/LineLength: 120`, `Metrics/MethodLength: 30`, `Minitest/MultipleAssertions: 4`, `Style/FrozenStringLiteralComment: always`
- `test/dummy/` excluded from RuboCop
- All source files have `# frozen_string_literal: true` comment

## Key files map

| File | Purpose |
|---|---|
| `lib/money_attribute.rb` | Entry point, requires all components |
| `lib/money_attribute/macro.rb` | `money_attribute` class method, column resolution, single vs composite setup |
| `lib/money_attribute/type.rb` | `ActiveRecord::Type` for single-column mode, registers `:mint_money` |
| `lib/money_attribute/converter.rb` | Normalizer/constructor for both modes |
| `lib/money_attribute/configuration.rb` | `MoneyAttribute.configure` DSL, `default_currency` |
| `lib/money_attribute/railtie.rb` | Rails boot: migration extensions, form builder, I18n, custom currencies |
| `lib/money_attribute/core_ext.rb` | `Numeric#to_money`, `String#to_money`, `#dollars`, `#euros` |
| `lib/money_attribute/form_builder_extension.rb` | `money_field`, `money_amount_field` helpers |
| `lib/money_attribute/migration_extensions/helper.rb` | `parse_money_args` — the complex column name resolver |
| `lib/money_attribute/migration_extensions/schema_statements.rb` | `add_money_attribute`, `remove_money_attribute` |
| `lib/money_attribute/migration_extensions/table_definition.rb` | `t.money_attribute`, `t.remove_money_attribute` |
| `test/dummy/app/models/financial_transaction.rb` | Integration example: all 5 money attributes with 3 storage modes |
