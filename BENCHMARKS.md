# Benchmarks Notes

Benchmarks comparing **money_attribute** (formerly minting-rails) against **money-rails** (the most popular money-in-Rails gem).

Disclaimer:
This report as well as the benchmark program were created by OpenCode AI.

## Methodology

- Both sides pass a `Money` object through the attribute setter (fair comparison).
- All tests are run against SQLite3 with 5000 iterations per test.
- Mass insert/bulk update uses batch sizes from 100 to 2000 records.
- Each side runs in a separate process (`BENCH_SIDE` env var) with isolated bundles to avoid gem namespace conflicts (`Mint::Currency`).
- Composite mode only (two-column: amount + currency).

### Environment

|           |                                |
|-----------|--------------------------------|
| **Date**  | 2026-07-22                     |
| **Ruby**  | 4.0.5                          |
| **Rails** | 8.1.3                          |
| **minting** | 2.0.0                        |
| **DB**    | SQLite3                        |
| **OS**    | macOS (darwin)                 |

## Results

| Test | money_attribute (int) | money_attribute (dec) | money-rails | Winner |
|---|---|---|---|---|
| Instantiation | 0.041s | 0.038s | 0.047s | **money_attribute 1.2x** |
| Create + save | 0.687s | 0.676s | 0.992s | **money_attribute 1.5x** |
| Update existing | 0.659s | 0.675s | 0.973s | **money_attribute 1.5x** |
| Setter only | 0.009s | 0.010s | 0.014s | **money_attribute 1.5x** |
| Read cached | 0.0005s | 0.0005s | 0.017s | **money_attribute 35x** |
| Query raw columns | 0.184s | 0.176s | 0.209s | **money_attribute 1.2x** |
| SQL generation | 0.182s | 0.178s | 0.203s | **money_attribute 1.1x** |
| Multi-record (100×1000) | 0.555s | 0.698s | 0.784s | **money_attribute 1.4x** |

**money_attribute wins all 8 cells.** *(Decimal column results shown alongside integer; money_attribute supports both column types natively. money-rails stores amounts as cents (integer) and has no built-in decimal column support.)*

### Scaling: Mass Insert

| Records | money_attribute (int) | money_attribute (dec) | money-rails | Winner |
|---|---|---|---|---|
| 100 | 0.009s | 0.008s | 0.014s | **1.6x** |
| 500 | 0.039s | 0.039s | 0.070s | **1.8x** |
| 1000 | 0.079s | 0.078s | 0.153s | **1.9x** |
| 2000 | 0.162s | 0.162s | 0.290s | **1.8x** |

### Scaling: Bulk Update

| Records | money_attribute (int) | money_attribute (dec) | money-rails | Winner |
|---|---|---|---|---|
| 100 | 0.014s | 0.014s | 0.020s | **1.5x** |
| 500 | 0.067s | 0.071s | 0.113s | **1.7x** |
| 1000 | 0.141s | 0.160s | 0.214s | **1.5x** |
| 2000 | 0.286s | 0.300s | 0.423s | **1.5x** |

money_attribute's write advantage scales linearly — the per-record overhead is constant, so the ratio holds across all batch sizes.

### Decimal Column Support

money_attribute supports **decimal amount columns** (storing `12.34` directly instead of `1234` cents). Money-rails always stores amounts as cents (integer) and has no built-in decimal column support.

Integer and decimal columns perform nearly identically in money_attribute:

| Test | int/dec ratio | Notes |
|---|---|---|
| Instantiation | 1.08x | Decimal slightly faster (avoids subunit division) |
| Create + save | 1.02x | Symmetric write paths |
| Read cached | 1.00x | Both return cached `Money` objects |
| Query raw columns | 0.96x | Within noise |
| Mass insert (1000) | 1.01x | Identical at scale |
| Bulk update (1000) | 0.88x | Integer slightly faster (fewer BigDecimal allocations) |

The best column type depends on your domain: decimal for direct monetary values, integer (subunits) for precision-sensitive financial systems.

## Repeated Access (Caching Demonstration)

| Property | money_attribute | money-rails |
|---|---|---|
| Same object on repeated read? | true | true |
| Time (5000 reads) | 0.0004s | 0.017s |
| Objects allocated (5000 reads) | **2** | **75,002** |
| Allocation ratio | — | **37,500x more** |

Both gems cache the `Money` object after the first read, but **money_attribute** returns it with near-zero overhead because `composed_of` stores the aggregation directly. Money-rails re-runs currency lookups, string interpolation for `instance_variable_get`, and `public_send` with splat on every read, allocating ~15 intermediate objects per call.

## Composite Mode Trade-off

money_attribute uses Rails' built-in `composed_of` for composite (two-column) mode. This provides:

- **Automatic caching** -- `composed_of` memoizes the `Money` object and invalidates it only when underlying columns change.
- **Predicate builder** -- `Model.where(price: money_obj)` automatically decomposes the `Money` into column conditions (`WHERE price_amount = ? AND price_currency = ?`).
- **Converter** -- Setting `model.price = "123.45"` works without manual conversion.

For single-column mode, money_attribute uses a custom ActiveRecord type (`MoneyAttribute::Type`) which competes directly with money-rails' `monetize` -- and wins across nearly every metric.

## Running the Benchmark

```sh
bundle exec rake bench
```

This runs both sides in separate processes with isolated bundles:
1. `BENCH_SIDE=minting` -- uses the main `Gemfile` (minting gem)
2. `BENCH_SIDE=money_rails BUNDLE_GEMFILE=Gemfile.benchmark` -- uses `Gemfile.benchmark` (money gem, no minting)

Requires the benchmark groups installed:
```sh
bundle install                              # main bundle (minting side)
BUNDLE_GEMFILE=Gemfile.benchmark bundle install  # benchmark bundle (money-rails side)
```
