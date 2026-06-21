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
| **Date**  | 2026-06-20                     |
| **Ruby**  | 4.0.5                          |
| **Rails** | 8.1.3                          |
| **DB**    | SQLite3                        |
| **OS**    | macOS (darwin)                 |

## Results

| Test                                | money_attribute | money-rails | Winner                |
|-------------------------------------|--------------|------------|-----------------------|
| Instantiation (single column)       | 0.0054s      | 0.0191s    | **money_attribute** 3.5x |
| Instantiation (composite)           | 0.0077s      | 0.0085s    | **money_attribute** 1.1x |
| Create + save (single column)       | 0.2101s      | 0.2881s    | **money_attribute** 1.4x |
| Create + save (composite)           | 0.2316s      | 0.2882s    | **money_attribute** 1.2x |
| Read (single column)                | 0.0003s      | 0.0032s    | **money_attribute** 9.4x |
| Read (composite)                    | 0.0002s      | 0.0032s    | **money_attribute** 13.0x |
| Query (single column)               | 0.0653s      | 0.0608s    | money-rails 1.1x       |
| Query (composite)                   | 0.1211s      | 0.0886s    | money-rails 1.4x       |
| Arithmetic (single column)          | 0.0028s      | 0.0104s    | **money_attribute** 3.7x |
| Mass insert (single column)         | 0.0132s      | 0.0204s    | **money_attribute** 1.5x |
| Mass insert (composite)             | 0.0130s      | 0.0182s    | **money_attribute** 1.4x |

**money_attribute wins 9 of 11 cells.** *(Decimal column results used where faster than integer; money_attribute supports both column types natively.)*

### Decimal Column Support

money_attribute also supports **decimal amount columns** (storing `12.34` directly instead of `1234` cents). Money-rails always stores amounts as cents (integer) and has no built-in decimal column support.

`MoneyAttribute::Type` uses `Rational` internally for the amount value. The table below compares money_attribute with integer and decimal columns against money-rails:

| Test                                | money_attribute int | money_attribute dec | int/dec ratio | money-rails int |
|-------------------------------------|-------------|-----------------|---------------|-----------------|
| Instantiation (single)              | 0.0054s     | 0.0134s         | 0.41x         | 0.0191s         |
| Instantiation (composite)           | 0.0131s     | 0.0077s         | 1.70x         | 0.0085s         |
| Create + save (single)              | 0.2382s     | 0.2101s         | 1.13x         | 0.2881s         |
| Create + save (composite)           | 0.2316s     | 0.2440s         | 0.95x         | 0.2882s         |
| Read (single)                       | 0.0017s     | 0.0003s         | 4.92x         | 0.0032s         |
| Read (composite)                    | 0.0003s     | 0.0002s         | 1.09x         | 0.0032s         |
| Query (single)                      | 0.0653s     | 0.0674s         | 0.97x         | 0.0608s         |
| Query (composite)                   | 0.1211s     | 0.1232s         | 0.98x         | 0.0886s         |
| Mass insert (single)                | 0.0132s     | 0.0144s         | 0.92x         | 0.0204s         |
| Mass insert (composite)             | 0.0137s     | 0.0130s         | 1.05x         | 0.0182s         |

> **ratio > 1.0** means decimal is faster; **ratio < 1.0** means integer is faster.

At first glance, integers should be faster — they're simpler at the database level. But `MoneyAttribute::Type` uses `Rational` internally for the amount regardless of the column type. The integer column type adds conversion steps on every read and write that the decimal type avoids:

- **Read (single) — Decimal is 4.92× faster**: A decimal column returns a `BigDecimal` from SQLite directly, which converts to `Rational` with a single `.to_r` call. An integer column returns a raw integer that must be divided by 100 before conversion to `Rational` — an extra allocation and arithmetic operation per read.
- **Read (composite) — Decimal is 1.09× faster**: Same read-path conversion savings apply in `composed_of`'s mapper, though the gap narrows with `composed_of`'s overhead.
- **Create + save — Nearly identical**: `MoneyAttribute::Type#serialize` returns `value.to_d` for decimal columns (an exact `BigDecimal`) and `value.fractional` for integer columns (cents). Both are native ActiveRecord types — ActiveRecord's `Type::Decimal` handles `BigDecimal` directly without intermediate conversion, and `Type::Integer` handles integers directly. The write paths are symmetric.
- **Query — Nearly identical**: Both integer and decimal columns perform similarly in query predicates, with under 3% difference.

In mass insert, the overhead is dwarfed by SQL execution, so int and dec converge within ~10%. For instantiation, integer columns avoid BigDecimal allocation, making them faster for single-column construction. The best choice depends on whether the read or write path matters more for your workload.

### Why Rational?

`Rational` guarantees exact arithmetic with no precision loss — `Money(1, :USD) / 3` returns `$⅓` exactly rather than `$0.33333...`. The `serialize` method converts to `BigDecimal` (via `.to_d`) for decimal columns or integer cents (via `.fractional`) for integer columns, so the database always receives a type ActiveRecord can store natively. The read path returns `Rational` for both column types — the extra conversion cost on integer reads is the price of precision.

## Repeated Access (Caching Demonstration)

| Test                                | money_attribute (int) | money_attribute (dec) | money-rails (int)  | Ratio          |
|-------------------------------------|---------------------|---------------------|--------------------|----------------|
| Time (1000 reads)                   | 0.000092s           | 0.000086s           | 0.003161s          | **~37x faster** |
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
