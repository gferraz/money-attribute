# REBRAND: minting-rails → money_attribute

## New identity

| Property | Current | New |
|---|---|---|
| Gem name | `minting-rails` | `money_attribute` |
| GitHub repo | `gferraz/minting-rails` | `gferraz/money-attribute` |
| Top-level module | `Mint` | `MoneyAttribute` |
| Concern module | `Mint::MoneyAttribute` | `MoneyAttribute::Macro` |
| AR type class | `Mint::MintMoneyType` | `MoneyAttribute::Type` |
| AR type key | `:mint_money` | `:money` |
| Railtie | `Mint::Railtie` | `MoneyAttribute::Railtie` |
| Config | `Mint::MoneyAttribute::Configuration` | `MoneyAttribute::Configuration` |
| Config DSL | `Mint.configure` | `MoneyAttribute.configure` |
| Default currency | `Mint.default_currency` | `MoneyAttribute.default_currency` |
| Converter | `Mint::MoneyAttribute::Parser` | `MoneyAttribute::Converter` |
| Generator | `rails g mint:initializer` | `rails g money_attribute:initializer` |
| Generated file | `config/initializers/minting.rb` | `config/initializers/money_attribute.rb` |
| Require | `require 'minting/rails'` | `require 'money_attribute'` |
| Gemspec | `minting-rails.gemspec` | `money_attribute.gemspec` |

## File operations

### Renames + moves (lib)

| From | To |
|---|---|
| `minting-rails.gemspec` | `money_attribute.gemspec` |
| `lib/minting/rails.rb` | `lib/money_attribute.rb` |
| `lib/minting/core_ext.rb` | `lib/money_attribute/core_ext.rb` |
| `lib/minting/railties.rb` | `lib/money_attribute/railtie.rb` |
| `lib/minting/money_attribute/configuration.rb` | `lib/money_attribute/configuration.rb` |
| `lib/minting/money_attribute/money_attribute.rb` | `lib/money_attribute/macro.rb` |
| `lib/minting/money_attribute/money_type.rb` | `lib/money_attribute/type.rb` |
| `lib/minting/money_attribute/parser.rb` | `lib/money_attribute/parser.rb` |
| `lib/minting/money_attribute/version.rb` | `lib/money_attribute/version.rb` |
| `lib/generators/minting/` | `lib/generators/money_attribute/` |
| `lib/generators/templates/minting.rb` | `lib/generators/templates/money_attribute.rb` |
| `lib/tasks/minting/` | `lib/tasks/money_attribute/` |

### Renames + moves (test)

| From | To |
|---|---|
| `test/minting/rails_test.rb` | `test/money_attribute/rails_test.rb` |
| `test/minting/money_attribute_test.rb` | `test/money_attribute/attribute_test.rb` |
| `test/minting/financial_transaction_test.rb` | `test/money_attribute/financial_transaction_test.rb` |
| `test/minting/composite_money_attribute_test.rb` | `test/money_attribute/composite_test.rb` |
| `test/minting/simple_money_attribute_test.rb` | `test/money_attribute/simple_test.rb` |

### Files unchanged (but content updated)

| File | What changes |
|---|---|
| `Gemfile` | Comment: gemspec name reference |
| `Gemfile.lock` | Auto-updated by `bundle install` |
| `Rakefile` | Benchmark task description |
| `.rubocop_todo.yml` | Gemspec path in exclude |
| `benchmark/comparison.rb` | Labels, class names, require path |
| `README.md` | All references |
| `CHANGELOG.md` | Add rename note under v0.9.0 |
| `BENCHMARKS.md` | Labels |
| `doc/agents/AGENTS.md` | Project name, paths |

## Module/class content changes

### `lib/money_attribute/macro.rb` (was `money_attribute.rb`)

- `module Mint; module MoneyAttribute` → `module MoneyAttribute; module Macro`
- `Mint.default_currency` → `MoneyAttribute.default_currency`
- `Currency.resolve!()` → `::Mint::Currency.resolve!()`
- `Money.from_fractional()` → `::Mint::Money.from_fractional()`
- `class_name: 'Mint::Money'` → `class_name: '::Mint::Money'`
- `:mint_money` → `:money` (AR type key)

### `lib/money_attribute/type.rb` (was `money_type.rb`)

- `module Mint` → `module MoneyAttribute`
- `class MintMoneyType` → `class Type`
- `Mint::Money.*` → `::Mint::Money.*`
- `when Mint::Money` → `when ::Mint::Money`
- `include Mint::MoneyAttribute` → `include MoneyAttribute::Macro`
- `register(:mint_money, Mint::MintMoneyType)` → `register(:money, MoneyAttribute::Type)`

### `lib/money_attribute/parser.rb`

- `module Mint; module MoneyAttribute` → `module MoneyAttribute`
- `Mint.default_currency` → `MoneyAttribute.default_currency`
- `Mint::Money` → `::Mint::Money`
- `Mint.parse()` → `::Mint.parse()`

### `lib/money_attribute/configuration.rb`

- `module Mint; module MoneyAttribute` → `module MoneyAttribute`
- `Currency.resolve!()` → `::Mint::Currency.resolve!()`

### `lib/money_attribute/railtie.rb` (was `railties.rb`)

- `module Mint` → `module MoneyAttribute`
- `Mint.locale_backend` → `::Mint.locale_backend`
- `Mint.config` → `MoneyAttribute.config`
- `Currency.register()` → `::Mint::Currency.register()`
- Generator require path updated

### `lib/money_attribute/core_ext.rb` (was `core_ext.rb`)

- `Mint.money()` → `::Mint.money()` (clarity, no functional change)

### `lib/money_attribute.rb` (entry point, was `rails.rb`)

- New file requiring all `money_attribute/` components
- No `ActiveSupport.on_load` (moved to `type.rb`)

### Generators

- `Mint::Generators::InitializerGenerator` → `MoneyAttribute::Generators::InitializerGenerator`
- Template: `Mint.configure` → `MoneyAttribute.configure`
- Generated file: `config/initializers/minting.rb` → `config/initializers/money_attribute.rb`

### Tests

- `module Mint` → `module MoneyAttribute` in all test files
- `Mint::MoneyAttribute::VERSION` → `VERSION` (inside module)
- `Mint.default_currency` → `MoneyAttribute.default_currency`
- `Mint.config` → `MoneyAttribute.config`
- `Mint.configure` → `MoneyAttribute.configure`
- `Mint::Railtie` → `Railtie`
- `Mint::Money` → `::Mint::Money` (from `minting` gem dependency)
- `Mint.money()` → `::Mint.money()`
- `Mint::Currency` → `::Mint::Currency`
- `MoneyAttribute::Parser` → `MoneyAttribute::Converter`
- `Mint::MoneyAttribute::Configuration` → `Configuration`

## Execution order

1. Write REBRAND.md (this file)
2. Rename gemspec + create `lib/money_attribute.rb` entry point
3. Move all files from `lib/minting/` → `lib/money_attribute/`
4. Update module/class names in all moved files
5. Move + update generators and tasks
6. Move + update tests
7. Update documentation
8. Update runner files (Gemfile, Rakefile, etc.)
9. Run tests, fix issues
10. Build gem, clean up
