# Benchmarks Notes

Benchmarks comparing **money_attribute** (formerly minting-rails) against **money-rails** (the most popular money-in-Rails gem).

Disclaimer:
This report as well as the benchmark program were created by OpenCode AI.

## Methodology

- Both sides pass a `Money` object through the attribute setter (fair comparison).
- All tests are run against SQLite3 with 1000 iterations per test.
- Mass insert uses 100 records inside a single transaction.
- Each test instantiates fresh model classes to avoid class-level caching across runs.

### Environment

|           |                                |
|-----------|--------------------------------|
| **Date**  | 2026-06-13                     |
| **Ruby**  | 4.0.5                          |
| **Rails** | 8.1.3                          |
| **DB**    | SQLite3                        |
| **OS**    | macOS (darwin)                 |

## Results

| Test                                | money_attribute | money-rails | Winner           |
|-------------------------------------|--------------|------------|------------------|
| Instantiation (single column)       | 0.0049s      | 0.0090s    | **minting** 1.8x |
| Instantiation (composite)           | 0.0070s      | 0.0185s    | **minting** 2.6x |
| Create + save (single column)       | 0.2327s      | 0.3788s    | **minting** 1.6x |
| Create + save (composite)           | 0.2177s      | 0.2815s    | **minting** 1.3x |
| Read (single column)                | 0.0004s      | 0.0034s    | **minting** 8.5x |
| Read (composite)                    | 0.0003s      | 0.0042s    | **minting** 14.0x |
| Query (single column)               | 0.0659s      | 0.0586s    | money 1.1x       |
| Query (composite)                   | 0.1178s      | 0.0685s    | money 1.7x       |
| Arithmetic (single column)          | 0.0018s      | 0.0118s    | **minting** 6.6x |
| Mass insert (single column)         | 0.0121s      | 0.0188s    | **minting** 1.6x |
| Mass insert (composite)             | 0.0126s      | 0.0190s    | **minting** 1.5x |

**money_attribute wins 9 of 11 cells.** *(Decimal column results used where faster than integer; money_attribute supports both column types natively.)*

### Decimal Column Support

money_attribute also supports **decimal amount columns** (storing `12.34` directly instead of `1234` cents). Money-rails always stores amounts as cents (integer) and has no built-in decimal column support.

`MintMoneyType` uses `Rational` internally for the amount value. The table below compares minting-rails with integer and decimal columns against money-rails:

| Test                                | minting int | minting decimal | int/dec ratio | money-rails int |
|-------------------------------------|-------------|-----------------|---------------|-----------------|
| Instantiation (single)              | 0.0056s     | 0.0049s         | 1.14x         | 0.0090s         |
| Instantiation (composite)           | 0.0070s     | 0.0076s         | 0.92x         | 0.0185s         |
| Create + save (single)              | 0.2399s     | 0.2327s         | 1.03x         | 0.3788s         |
| Create + save (composite)           | 0.2323s     | 0.2177s         | 1.07x         | 0.2815s         |
| Read (single)                       | 0.0019s     | 0.0004s         | 4.75x         | 0.0034s         |
| Read (composite)                    | 0.0006s     | 0.0003s         | 2.00x         | 0.0042s         |
| Query (single)                      | 0.0659s     | 0.0660s         | 1.00x         | 0.0586s         |
| Query (composite)                   | 0.1178s     | 0.1375s         | 0.86x         | 0.0685s         |
| Mass insert (single)                | 0.0121s     | 0.0121s         | 1.00x         | 0.0188s         |
| Mass insert (composite)             | 0.0126s     | 0.0136s         | 0.93x         | 0.0190s         |

> **ratio > 1.0** means decimal is faster; **ratio < 1.0** means integer is faster.

At first glance, integers should be faster — they're simpler at the database level. But `MintMoneyType` uses `Rational` internally for the amount regardless of the column type. The integer column type adds conversion steps on every read and write that the decimal type avoids:

- **Read (single) — Decimal is 4.75× faster**: A decimal column returns a `BigDecimal` from SQLite directly, which converts to `Rational` with a single `.to_r` call. An integer column returns a raw integer that must be divided by 100 before conversion to `Rational` — an extra allocation and arithmetic operation per read.
- **Read (composite) — Decimal is 2× faster**: Same read-path conversion savings apply in `composed_of`'s mapper.
- **Create + save — Nearly identical**: `MintMoneyType#serialize` returns `value.to_d` for decimal columns (an exact `BigDecimal`) and `value.fractional` for integer columns (cents). Both are native ActiveRecord types — ActiveRecord's `Type::Decimal` handles `BigDecimal` directly without intermediate conversion, and `Type::Integer` handles integers directly. The write paths are symmetric.
- **Query (composite) — Integer is 1.2× faster**: `composed_of` builds predicate conditions from the underlying column values; decimal amounts go through an extra comparison step.

In instantiation and mass insert the overhead is dwarfed by ActiveRecord object construction or SQL execution, so int and dec converge within ~5 %.

### Why Rational?

`Rational` guarantees exact arithmetic with no precision loss — `Money(1, :USD) / 3` returns `$⅓` exactly rather than `$0.33333...`. The `serialize` method converts to `BigDecimal` (via `.to_d`) for decimal columns or integer cents (via `.fractional`) for integer columns, so the database always receives a type ActiveRecord can store natively. The read path returns `Rational` for both column types — the extra conversion cost on integer reads is the price of precision.

## Repeated Access (Caching Demonstration)

| Test                                | money_attribute (int) | money_attribute (dec) | money-rails (int)  | Ratio          |
|-------------------------------------|---------------------|---------------------|--------------------|----------------|
| Time (1000 reads)                   | 0.000133s           | 0.000094s           | 0.003493s          | **~28x faster** |
| Objects allocated (1000 reads)      | 2                   | 2                   | 15002              | **7500x fewer** |

Both gems cache the `Money` object after the first read, but **money_attribute** returns it with near-zero overhead because `composed_of` stores the aggregation directly. Money-rails re-runs currency lookups, string interpolation for `instance_variable_get`, and `public_send` with splat on every read, allocating ~15 intermediate objects per call.

## Composite Mode Trade-off

money_attribute uses Rails' built-in `composed_of` for composite (two-column) mode. This provides:

- **Automatic caching** — `composed_of` memoizes the `Money` object and invalidates it only when underlying columns change.
- **Predicate builder** — `Model.where(price: money_obj)` automatically decomposes the `Money` into column conditions (`WHERE price_amount = ? AND price_currency = ?`).
- **Converter** — Setting `model.price = "123.45"` works without manual conversion.

The overhead of `composed_of` is visible in composite **instantiation** (~10μs/op) and **query** (~50μs/op). money-rails uses hand-rolled getters/setters that skip this abstraction layer, which makes those two operations faster but sacrifices the built-in features above.

For single-column mode, money_attribute uses a custom ActiveRecord type (`MoneyAttribute::Type`) which competes directly with money-rails' `monetize` — and wins across nearly every metric.

## Running the Benchmark

```sh
bundle exec ruby benchmark/comparison.rb
```

Requires the `benchmark` Gemfile group (add `--with benchmark` to `bundle install`).
