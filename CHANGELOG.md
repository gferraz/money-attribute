# Changelog

## [Unreleased]

### Breaking changes
- Removed `enabled_currencies` configuration option. All registered currencies are now always valid.

### Improvements
- AI suggested refactorings (see [review](doc/agents/review-2026-06-12.md))

## [v0.7.1](https://github.com/gferraz/minting-rails/releases/tag/v0.7.1) (2026-06-09)

[Full Changelog](https://github.com/gferraz/minting-rails/compare/v0.7.0...v0.7.1)

# Improvementes
- Enabled github CI
- Update minting to 1.7.0

## [v0.7.0](https://github.com/gferraz/minting-rails/releases/tag/v0.7.0) (2026-06-09)

[Full Changelog](https://github.com/gferraz/minting-rails/compare/v0.4.3...v0.7.0)

### Breaking changes

- Invert the mapping of money_attributes
- Accepts columns that sotre money amounts as integers
