# AGENTS for minting-rails

## Purpose
- `minting-rails` is a Rails gem that integrates Minting money objects with ActiveRecord models.
- The highest-priority task is adapting this gem to work with the latest `minting` gem version while preserving the current `money_attribute` API and Rails compatibility.

## Key code areas
- `lib/minting/rails.rb` — Railtie that loads the generator and registers configured currencies on app boot.
- `lib/minting/money_attribute.rb` — entrypoint that requires core extensions, configuration, money attribute support, and railtie.
- `lib/minting/money_attribute/money_attribute.rb` — defines `money_attribute`, normalization behavior, and composed money attribute lookup.
- `lib/minting/money_attribute/money_type.rb` — registers Active Record type `:mint_money` and enforces a fixed currency for typed attributes.
- `lib/minting/money_attribute/configuration.rb` — holds gem-level Minting configuration and currency validation logic.

## Important behavior to preserve
- `money_attribute :price, currency: 'USD'` uses a single DB column with a fixed `USD` currency and normalizes assignments.
- `money_attribute :price` without a currency uses `price_amount` + `price_currency` composition and `Mint.default_currency` for plain numeric/string assignments.
- The gem relies on these Minting API surfaces:
  - `Mint.money`
  - `Mint.currency`
  - `Mint.valid_currency?`
  - `Mint.currencies`
  - `Mint::Money` and `Mint::Currency`
  - `Mint.configure`
- `Mint.assert_valid_currency!` is a central compatibility gate: changing Minting currency registration behavior may require updating this gem.

## Tests and workflows
- Run the full test suite with `bundle exec rake test`.
- The gem is built and packaged with standard Bundler gem tasks from `Rakefile`.
- Test helper loads the dummy Rails app under `test/dummy` and uses its migrations and fixtures.

## Adaptation guidance for latest Minting
- Update the `minting` dependency in `minting-rails.gemspec`.
- Verify that `Mint.money` still accepts Numeric, String, and `Mint::Money`, and that `to_money` interop is preserved.
- Confirm `Mint.currency`, `Mint.valid_currency?`, and `Mint.currencies` still behave consistently for currency validation.
- Confirm `Mint.configure` and `added_currencies` registration semantics remain compatible when the engine boots.
- Run the dummy app tests after any compatibility change and update `README.md` examples only if the Minting public API changed.

## Notes for agents
- Prefer small, targeted compatibility edits over broad implementation rewrites.
- If you need to change Minting API assumptions, add regression tests around the affected parsing or type-registration behavior.
- Avoid duplicating existing README documentation; keep the focus on code-level intent and version compatibility.
