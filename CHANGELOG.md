# Changelog

## [Unreleased]

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
