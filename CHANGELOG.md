# Changelog

## [1.1.0] (2026-07-22)

### Improvements
- **minting 2.0.0 compatibility** — `to_fs(:currency)` replaced with `to_fs` in form builder helpers and tests; minting 2.0's default format (`%<symbol>s%<amount>f`) produces identical output.
- **Benchmark isolation** — money-rails comparison now runs in a separate process with its own `Gemfile.benchmark`, avoiding the `Mint::Currency` namespace collision between the `minting` and `money` gems.
- **Benchmark expanded** — New test scenarios: update existing record, setter-only, SQL generation, multi-record deserialization stress test, and scaling tests (mass insert + bulk update at 100/500/1000/2000 records).
- **Benchmark report updated** — money_attribute wins all 8 core cells and all scaling tests against money-rails.

## [1.0.0] (2026-07-06)

### Stable release

After extensive iteration through the 0.x series, MoneyAttribute is now stable at 1.0.0.

- **API frozen** — `money_attribute`, `money_amount`, migration helpers, configuration, and form helpers are stable. No breaking changes planned without a major version bump.
- **Nil currency fallback** — When the currency column is nil in composite mode, the default currency is used instead of raising.
- **Generator type registration deferred** — `rails g model` support for `money_attribute`/`money_amount` types moved to post-1.0 to avoid monkey-patching Rails internals before the API stabilizes.

### Invalid currency fallback (XXX)

When the currency column contains a value that is not a registered ISO currency (legacy codes, data corruption), the constructor lambda resolves it to **XXX** (ISO 4217 "No Currency") instead of raising `Mint::UnknownCurrency`. The monetary amount is preserved and the record remains queryable:

```ruby
Offer.where(price_currency: 'XXX') # find and fix corrupted records
```

This uses `Mint::Currency.resolve` (non-bang) with a `||` chain to XXX — no `rescue` needed.

### Edge case hardening
- **Migration helper reversibility** — Added tests for `add_money_attribute` / `add_money_amount` with `:fiat_integer`, `:crypto_decimal`, custom column mappings, and currency limits.
- **Large value round-trips** — Decimal amounts up to 100 trillion and integer amounts near BIGINT max verified.
- **Test count** — 130 tests, 381 assertions, 0 failures.
- **RuboCop clean** — All 36 inline `# rubocop:disable`/`# rubocop:enable` comments removed from the codebase. Zero offenses across all files.
- **Benchmark scripts restructured** — `comparison.rb` extracted into 13 benchmark methods; `report.rb` split into smaller methods with keyword args. Benchmark excluded from RuboCop.
- **Rake task fix** — Removed broken `:environment` dependency from `bench`, `bench:report`, and `test_db_migrate` tasks (standalone gem, no Rails app to provide it).
- **`money_amount` currency removed** — `money_amount` no longer accepts a `currency:` argument; always uses `MoneyAttribute.default_currency`.
- **Configuration thread-safe** — Replaced class instance variables with closure-based pattern to satisfy `ThreadSafety/ClassInstanceVariable`.
- **Migration helper validation** — 8 new tests covering precision/scale rejection, invalid type, and currency limit guards.

## [v0.14.5] (2026-06-29)

[Full Changelog](https://github.com/gferraz/money-attribute/compare/v0.14.4...v0.14.5)

### Improvements
- **Use `to_fs(:currency)` instead of `to_s(:currency)`** — Form builder helpers and tests now call `to_fs(:currency)` for money formatting, aligning with modern Rails conventions.
- **Configuration frozen after initialization** — `MoneyAttribute::Configuration` supports `#freeze` to prevent runtime mutation; Rails boot freezes the config object.
- **Core extensions simplified** — Removed redundant `remove_method` calls from `Numeric#to_money` and `String#to_money`; the minting gem no longer defines conflicting methods.
- **Converter error handling** — `Converter#parse` raises `ArgumentError` for unrecognized input types instead of letting `Money.parse` raise a lower-level error.
- **AGENTS.md rewritten** — Full agent documentation with commands, architecture, gotchas, and key files map.

### Dependencies
- Removed `solargraph` from development group.
- Updated Gemfile.lock dependency versions.

## [v0.14.4] (2026-06-26)

[Full Changelog](https://github.com/gferraz/money-attribute/compare/v0.14.2...v0.14.4)

### Improvements
- **register_custom_currencies! raises ArgumentError** — Invalid currency configuration (missing `:currency`, `:subunit`, or `:symbol` keys) now raises `ArgumentError` with a descriptive message instead of failing silently. Registrations that fail because the currency already exists are still silently skipped.

### Tests
- **Integration tests for FormBuilderExtension** — New `form_builder_extension_test.rb` covers `money_field` and `money_amount_field` rendering, DOM id conventions, form submission, and CRUD flows via the dummy app's `FinancialTransactionsController`.

## [v0.14.2] (2026-06-26)

[Full Changelog](https://github.com/gferraz/money-attribute/compare/v0.14.1...v0.14.2)

### Fixes
- **Remaining `:mint_money` renames** — Follow-up to v0.14.1: fixed missing `:money_type` references that were still using the old type key.

## [v0.14.1] (2026-06-26)

[Full Changelog](https://github.com/gferraz/money-attribute/compare/v0.14.0...v0.14.1)

### Fixes
- **`:money` type renamed to `:mint_money`** — The internal `ActiveRecord::Type` key was changed from `:money` back to `:mint_money` to avoid conflicts with the PostgreSQL adapter's built-in `:money` type. This affects `attribute(name, :mint_money, ...)` calls.
- **Error in `money_attribute` macro** — Fixed a bug in column resolution that could produce incorrect mapping.

## [v0.14.0] (2026-06-24)

[Full Changelog](https://github.com/gferraz/money-attribute/compare/v0.13.0...v0.14.0)

### Improvements
- **Nil-safe `composed_of` constructor** — When the currency column is `nil` or blank, the constructor now falls back to `MoneyAttribute.default_currency` instead of raising `ArgumentError`. This means views can safely render `ft.amount` without rescue helpers.
- **Single-input form helpers** — `money_field` and `money_amount` now render a single text input with the formatted money string (e.g., `R$1,234.56`). Currency is detected from the typed format (`$1,500.00` → USD, `R$ 3.000,00` → BRL) or falls back to the default currency when no symbol is present.

### Other
- **`Parser` renamed to `Converter`** — better reflects the class's role (converting various input types into `Mint::Money` objects).

## [v0.13.0] (2026-06-23)

[Full Changelog](https://github.com/gferraz/money-attribute/compare/v0.12.0...v0.13.0)

### Breaking changes
- **Migration DSL renamed** — `t.money` → `t.money_attribute`, `t.remove_money` → `t.remove_money_attribute`, `add_money` → `add_money_attribute`, `remove_money` → `remove_money_attribute` to avoid conflict with Rails PostgreSQL adapter's `t.money`.
- **Currency column inference for `:amount`** — `t.money_attribute :amount` now infers the currency column as `currency` (not `amount_currency`), matching the model's column resolution (step 3).

### Improvements
- **Dummy app migrations** — All test migrations updated to use the new DSL helpers.

## [v0.12.0] (2026-06-23)

[Full Changelog](https://github.com/gferraz/money-attribute/compare/v0.11.0...v0.12.0)

### Breaking changes
- **Migration API: all options now hash-nested** — `amount:` and `currency:` consistently accept a hash with `column:`, `type:`, `null:`, `default:`, `precision:`, `scale:`, and `limit:` keys. Flat symbol column overrides (`amount: :foo`) replaced with `amount: { column: :foo }`. Flat `type:` and `currency_limit:` removed — use `amount: { type: }` and `currency: { limit: }` instead. The only remaining flat sentinel is `currency: false` (suppress currency column).

### Improvements
- **README** — Added migration defaults paragraph (`decimal(16,4)` + string), documented partial `mapping:` (single key), fixed column resolution table, noted that composite mode does not enforce currency.
- **Precision/scale stripped for non-decimal types** — Passing `precision:`/`scale:` with `type: :integer` or `:bigint` now silently drops them instead of potentially causing migration errors on strict databases.

### Other
- dependecies updated

## [v0.11.0](https://github.com/gferraz/money-attribute/releases/tag/v0.11.0) (2026-06-23)

[Full Changelog](https://github.com/gferraz/money-attribute/compare/v0.10.0...v0.11.0)

### Breaking changes
- **minting 1.9.0 compatibility** — `from_fractional` replaced with `from_subunits` (Type deserialize, Macro constructors) and `value.fractional` replaced with `value.subunits` (Type serialize). Minimum minting dependency bumped to `>= 1.9.0`.

### Improvements
- **Migration helpers** — `:decimal` amount columns now default to `precision: 16, scale: 4` to prevent truncation on databases that require explicit precision/scale (MySQL). Explicit `amount: { precision:, scale: }` overrides the default. Covers all registered currencies (max subunit is 4).

## [v0.10.0](https://github.com/gferraz/money-attribute/releases/tag/v0.10.0) (2026-06-20)

[Full Changelog](https://github.com/gferraz/money-attribute/compare/v0.9.0...v0.10.0)

### New features
- **Migration helpers** — `add_money_attribute :products, :price` / `remove_money_attribute :products, :price` / `t.money_attribute :price` added as ActiveRecord migration DSL methods. Supports composite (`price` + `price_currency`) and single-column (`currency: false`), explicit column mapping (`amount: :a, currency: :c`), column type (`type: :integer`), and currency string limit (`currency_limit: 3`). Reversible in `change`.

### Improvements
- **`allow_nil`** — nil values are always allowed, no opt-in needed (README and roadmap updated).
- **Dead code removed** — `default_format` config attribute and stale `minting_rails` rake task.
- **README** — comparative table shows `add_money_attribute` / `t.money_attribute`, roadmap deduplicated.

## [v0.9.0](https://github.com/gferraz/money-attribute/releases/tag/v0.9.0) (2026-06-20)

[Full Changelog](https://github.com/gferraz/money-attribute/compare/v0.8.3...v0.9.0)

### Breaking changes
- **Rebrand** — Gem renamed from `minting-rails` to `money_attribute`.
- Module `Mint::MoneyAttribute` → `MoneyAttribute::Macro`.
- Class `Mint::MintMoneyType` → `MoneyAttribute::Type`.
- AR type key `:mint_money` → `:money`.
- Config methods moved from `Mint.configure`/`Mint.config`/`Mint.default_currency` to `MoneyAttribute.configure`/`MoneyAttribute.config`/`MoneyAttribute.default_currency`.
- Generator renamed from `rails g mint:initializer` to `rails g money_attribute:initializer` (creates `config/initializers/money_attribute.rb`).
- Entry point changed from `require 'minting/rails'` to `require 'money_attribute'`.

## [v0.8.3](https://github.com/gferraz/minting-rails/releases/tag/v0.8.3) (2026-06-20)

[Full Changelog](https://github.com/gferraz/minting-rails/compare/v0.8.2...v0.8.3)

### Improvements
- **Resolution priority system** — `money_attribute :name` now resolves columns through a 5-step priority table (explicit mapping, `name_currency` convention, generic `currency` for `amount`, convention composite `name_amount`/`name_currency`, single-column fallback). Resolution is order-independent.
- **Constructor simplification** — Replaced `money_constructor_for` lambdas with Symbol constructors (`:from`/`:from_fractional`), leveraging Rails' native Symbol support in `composed_of`.
- **Code reorganization** — Split `money_attribute` internals into preparation (no side effects) and configuration (registers types, normalizers, `composed_of`). Hoisted `Parser` construction to eliminate duplication.
- **New tests** — Added tests for all five resolution steps (convention composite, explicit mapping, order-independence, single-column), FinancialTransaction model-loading validation, and integration across 5 coexisting money attributes.
- **Updated README** — Added resolution priority table and single-table example covering all five steps.

## [v0.8.2](https://github.com/gferraz/minting-rails/releases/tag/v0.8.2) (2026-06-19)

[Full Changelog](https://github.com/gferraz/minting-rails/compare/v0.8.1...v0.8.2)

### Improvements
- **I18n support** — Money amounts are now formatted using the ActiveRecord I18n locale (`number.currency.format`). Locale files are no longer installed by default; users can run `rails g minting:locale:install` to customize.
- **Negative and zero formatting** — Negative and zero amounts can have different formats
- update minting dependency

## [v0.8.1](https://github.com/gferraz/minting-rails/releases/tag/v0.8.1) (2026-06-17)

[Full Changelog](https://github.com/gferraz/minting-rails/compare/v0.8.0...v0.8.1)

### Breaking changes
- Bumped minimum `minting` dependency to `>= 1.8.1`.

### Improvements
- Removed `Mint.assert_valid_currency!` — replaced with `Currency.resolve!`.
- Removed `Mint.currency` usage — replaced with `Currency.resolve` / `Currency.for_code`.
- Removed `Mint.register_currency` usage — replaced with `Currency.register`.
- Removed `Mint::Money.create` calls — replaced with `Mint::Money.from`.

### Bug fixes
- Fixed `@currency.multiplier` → `@currency.fractional_multiplier` to match `Currency` Data.define API.
- Fixed zero-money serialization crash (`Integer#to_d` argument error in bigdecimal 4.1.2).

## [v0.8.0](https://github.com/gferraz/minting-rails/releases/tag/v0.8.0) (2026-06-14)

[Full Changelog](https://github.com/gferraz/minting-rails/compare/v0.7.1...v0.8.0)

### Breaking changes
- Removed `enabled_currencies` configuration option. All registered currencies are now always valid.
- Removed deprecated `lib/minting/rails.rb` and `lib/minting/railties.rb` entry points.
- Removed `AGENTS.md` — project conventions

### Improvements
- **Benchmark suite** — Added `benchmark/comparison.rb` with competitive benchmarks against money-rails, including integer and decimal column support across 11 test scenarios (instantiation, persistence, reads, queries, arithmetic, mass insert, caching). (OpenCode AI)
- **BENCHMARKS.md** — Published benchmark report with full results, decimal column analysis, Rational vs BigDecimal trade-off, and caching demonstration. (OpenCode AI)
- **README overhaul** — Added vs money-rails comparison table, side-by-side code examples, honest gap analysis, and a roadmap for future improvements. (OpenCode AI)
- **Better error messages** — Missing attribute mapping names now raise a clear `ArgumentError`.
- **Test coverage** — Added `simple_money_attribute_test.rb` with comprehensive edge cases; improved existing `money_attribute_test.rb` assertions. (OpenCode AI)
- **Code cleanup** — Removed stale test files (`rails_test.rb`, `simple_offer_test.rb`), removed unused initializer template, small refactoring across money_attribute and configuration modules.

## [v0.7.1](https://github.com/gferraz/minting-rails/releases/tag/v0.7.1) (2026-06-09)

[Full Changelog](https://github.com/gferraz/minting-rails/compare/v0.7.0...v0.7.1)

### Improvements
- Enabled GitHub CI
- Update minting to 1.7.0

## [v0.7.0](https://github.com/gferraz/minting-rails/releases/tag/v0.7.0) (2026-06-09)

[Full Changelog](https://github.com/gferraz/minting-rails/compare/v0.4.3...v0.7.0)

### Breaking changes

- Invert the mapping of money_attributes
- Accepts columns that store money amounts as integers
