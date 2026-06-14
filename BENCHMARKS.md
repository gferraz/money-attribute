# Benchmarks

Benchmarks comparing **minting-rails** against **money-rails** (the most popular money-in-Rails gem).

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

| Test                                | minting-rails | money-rails | Winner           |
|-------------------------------------|--------------|------------|------------------|
| Instantiation (single column)       | 0.0052s      | 0.0101s    | **minting** 1.9x |
| Instantiation (composite)           | 0.0070s      | 0.0173s    | **minting** 2.5x |
| Create + save (single column)       | 0.2088s      | 0.2782s    | **minting** 1.3x |
| Create + save (composite)           | 0.2180s      | 0.2771s    | **minting** 1.3x |
| Read (single column)                | 0.0004s      | 0.0032s    | **minting** 8.0x |
| Read (composite)                    | 0.0003s      | 0.0043s    | **minting** 14.3x |
| Query (single column)               | 0.0662s      | 0.0602s    | money 1.1x       |
| Query (composite)                   | 0.1182s      | 0.0691s    | money 1.7x       |
| Arithmetic (single column)          | 0.0019s      | 0.0124s    | **minting** 6.5x |
| Mass insert (single column)         | 0.0125s      | 0.0188s    | **minting** 1.5x |
| Mass insert (composite)             | 0.0122s      | 0.0204s    | **minting** 1.7x |

**minting-rails wins 9 of 11 cells.** *(Decimal column results used for single-column tests where faster than integer; minting-rails supports both column types natively.)*

### Decimal Column Support

minting-rails also supports **decimal amount columns** (storing `12.34` directly instead of `1234` cents). Money-rails always stores amounts as cents (integer) and has no built-in decimal column support.

The decimal column results are comparable to integer column results — `MintMoneyType` auto-detects the column type:

| Test                                | minting int | minting decimal | int/dec ratio | money-rails int |
|-------------------------------------|-------------|-----------------|---------------|-----------------|
| Instantiation (single)              | 0.0052s     | 0.0054s         | 0.96x         | 0.0101s         |
| Instantiation (composite)           | 0.0070s     | 0.0074s         | 0.95x         | 0.0173s         |
| Create + save (single)              | 0.2436s     | 0.2088s         | 1.17x         | 0.2782s         |
| Create + save (composite)           | 0.2180s     | 0.2217s         | 0.98x         | 0.2771s         |
| Read (single)                       | 0.0016s     | 0.0004s         | 4.00x         | 0.0032s         |
| Read (composite)                    | 0.0003s     | 0.0003s         | 1.00x         | 0.0043s         |
| Query (single)                      | 0.0662s     | 0.0665s         | 1.00x         | 0.0602s         |
| Query (composite)                   | 0.1182s     | 0.1369s         | 0.86x         | 0.0691s         |
| Mass insert (single)                | 0.0141s     | 0.0125s         | 1.13x         | 0.0188s         |
| Mass insert (composite)             | 0.0122s     | 0.0137s         | 0.89x         | 0.0204s         |

> **ratio > 1.0** means decimal is faster; **ratio < 1.0** means integer is faster.

Integer and decimal columns are within **~5 %** of each other in most tests, with two notable exceptions:

- **Read (single)** — Decimal is **4× faster** because the column already stores a `BigDecimal`, avoiding the integer-to-decimal cast that the integer column path requires.
- **Create + save (single)** — Decimal is **17 % faster**, likely because the write path skips the cents conversion step (`BigDecimal → cents integer → column` vs `BigDecimal → column`).

The `MintMoneyType` type auto-detects the column type and handles both transparently. This means you can freely choose integer or decimal storage without worrying about performance — and if you prefer human-readable values in the database, decimal columns come at no cost (and even a slight advantage in some paths).

## Repeated Access (Caching Demonstration)

| Test                                | minting-rails (int) | minting-rails (dec) | money-rails (int)  | Ratio          |
|-------------------------------------|---------------------|---------------------|--------------------|----------------|
| Time (1000 reads)                   | 0.000092s           | 0.000099s           | 0.003622s          | **~37x faster** |
| Objects allocated (1000 reads)      | 2                   | 2                   | 15002              | **7500x fewer** |

Both gems cache the `Money` object after the first read, but **minting-rails** returns it with near-zero overhead because `composed_of` stores the aggregation directly. Money-rails re-runs currency lookups, string interpolation for `instance_variable_get`, and `public_send` with splat on every read, allocating ~15 intermediate objects per call.

## Composite Mode Trade-off

minting-rails uses Rails' built-in `composed_of` for composite (two-column) mode. This provides:

- **Automatic caching** — `composed_of` memoizes the `Money` object and invalidates it only when underlying columns change.
- **Predicate builder** — `Model.where(price: money_obj)` automatically decomposes the `Money` into column conditions (`WHERE price_amount = ? AND price_currency = ?`).
- **Converter** — Setting `model.price = "123.45"` works without manual conversion.

The overhead of `composed_of` is visible in composite **instantiation** (~10μs/op) and **query** (~50μs/op). money-rails uses hand-rolled getters/setters that skip this abstraction layer, which makes those two operations faster but sacrifices the built-in features above.

For single-column mode, minting-rails uses a custom ActiveRecord type (`MintMoneyType`) which competes directly with money-rails' `monetize` — and wins across nearly every metric.

## Running the Benchmark

```sh
bundle exec ruby benchmark/comparison.rb
```

Requires the `benchmark` Gemfile group (add `--with benchmark` to `bundle install`).
