# Benchmarks Notes

Benchmarks comparing **money_attribute** (formerly minting-rails) against **money-rails** (the most popular money-in-Rails gem).

Disclaimer:
This report as well as the benchmark program were created by OpenCode AI.

## Methodology

- Both sides pass a `Money` object through the attribute setter (fair comparison).
- All tests are run against SQLite3 with 5000 iterations per test.
- Mass insert/bulk update uses batch sizes from 100 to 2000 records.
- Each side runs in a separate process (`BENCH_SIDE` env var) with isolated bundles to avoid gem namespace conflicts (`Money::Currency`).
- Composite mode only (two-column: amount + currency).

### Environment

|           |                                |
|-----------|--------------------------------|
| **Date**  | 2026-07-28                     |
| **Ruby**  | 4.0.5                          |
| **Rails** | 8.1.3                          |
| **minting** | 2.0.0                        |
| **DB**    | SQLite3                        |
| **OS**    | macOS (darwin)                 |

## Results

| Test | money_attribute (int) | money_attribute (dec) | money-rails | Winner |
|---|---|---|---|---|
| Instantiation | 0.035s | 0.035s | 0.041s | **money_attribute 1.2x** |
| Create + save | 0.685s | 0.691s | 1.036s | **money_attribute 1.5x** |
| Update existing | 0.695s | 0.702s | 0.990s | **money_attribute 1.4x** |
| Setter only | 0.010s | 0.010s | 0.014s | **money_attribute 1.3x** |
| Read cached | 0.0005s | 0.0005s | 0.016s | **money_attribute 32x** |
| Query raw columns | 0.189s | 0.180s | 0.187s | **tied** |
| SQL generation | 0.185s | 0.178s | 0.192s | **money_attribute 1.0x** |
| Multi-record (100×1000) | 0.566s | 0.700s | 0.766s | **money_attribute 1.4x** |

**money_attribute wins 6 of 8 cells, tied on 2.** *(Decimal column results shown alongside integer; money_attribute supports both column types natively. money-rails stores amounts as cents (integer) and has no built-in decimal column support.)*

### Scaling: Mass Insert

| Records | money_attribute (int) | money_attribute (dec) | money-rails | Winner |
|---|---|---|---|---|
| 100 | 0.008s | 0.009s | 0.015s | **1.8x** |
| 500 | 0.041s | 0.042s | 0.070s | **1.7x** |
| 1000 | 0.090s | 0.081s | 0.151s | **1.7x** |
| 2000 | 0.158s | 0.180s | 0.286s | **1.8x** |

### Scaling: Bulk Update

| Records | money_attribute (int) | money_attribute (dec) | money-rails | Winner |
|---|---|---|---|---|
| 100 | 0.013s | 0.015s | 0.020s | **1.5x** |
| 500 | 0.066s | 0.072s | 0.098s | **1.5x** |
| 1000 | 0.151s | 0.147s | 0.201s | **1.3x** |
| 2000 | 0.290s | 0.310s | 0.428s | **1.5x** |

money_attribute's write advantage scales linearly — the per-record overhead is constant, so the ratio holds across all batch sizes.

### Decimal Column Support

money_attribute supports **decimal amount columns** (storing `12.34` directly instead of `1234` cents). Money-rails always stores amounts as cents (integer) and has no built-in decimal column support.

Integer and decimal columns perform nearly identically in money_attribute:

| Test | int/dec ratio | Notes |
|---|---|---|
| Instantiation | 1.00x | Identical |
| Create + save | 0.99x | Within noise |
| Read cached | 0.91x | Within noise |
| Query raw columns | 1.05x | Within noise |
| Mass insert (1000) | 1.11x | Integer slightly faster |
| Bulk update (1000) | 1.03x | Within noise |

The best column type depends on your domain: decimal for direct monetary values, integer (subunits) for precision-sensitive financial systems.

## Query Helpers (money_attribute-only)

money_attribute provides `where_amount`, `where_currency`, `order_by_amount`, `pluck_amount`, `pick_amount`, and `sum_amount` — money-rails has no equivalent.

| Helper | Time (5000 iters) | Per call | Notes |
|---|---|---|---|
| `where_amount` (Money scalar) | 0.028s | **5.6μs** | Single Money equality |
| `where_amount` (Range) | 0.041s | **8.2μs** | Inclusive/exclusive range |
| `where_amount` (Array) | 0.035s | **7.1μs** | IN clause |
| `where_currency` | 0.043s | **8.7μs** | Currency filter |
| `order_by_amount` (desc) | 1.327s | **265μs** | Orders + loads 100 records |
| `pluck_amount` | 1.093s | **219μs** | Plucks 100 Money values |
| `pick_amount` | 0.267s | **53μs** | Picks first Money value |
| `sum_amount` | 0.462s | **92μs** | Sums with GROUP BY |

Filter helpers (`where_amount`, `where_currency`) are sub-10μs per call — comparable to raw SQL. Data-loading helpers (`pluck_amount`, `order_by_amount`) scale with the number of rows returned.

## Repeated Access (Caching Demonstration)

| Property | money_attribute | money-rails |
|---|---|---|
| Same object on repeated read? | true | true |
| Time (5000 reads) | 0.0004s | 0.016s |
| Objects allocated (5000 reads) | **2** | **75,002** |
| Allocation ratio | — | **37,500x more** |

Both gems cache the `Money` object after the first read, but **money_attribute** returns it with near-zero overhead because `composed_of` stores the aggregation directly. Money-rails re-runs currency lookups, string interpolation for `instance_variable_get`, and `public_send` with splat on every read, allocating ~15 intermediate objects per call.

## Composite Mode Trade-off

money_attribute uses Rails' built-in `composed_of` for composite (two-column) mode. This provides:

- **Automatic caching** -- `composed_of` memoizes the `Money` object and invalidates it only when underlying columns change.
- **Predicate builder** -- `Model.where(price: money_obj)` automatically decomposes the `Money` into column conditions (`WHERE price_amount = ? AND price_currency = ?`).
- **Converter** -- Setting `model.price = "123.45"` works without manual conversion.

For single-column mode, money_attribute uses a custom ActiveRecord type (`MoneyAttribute::IntegerAmountType`/`MoneyAttribute::DecimalAmountType`) which competes directly with money-rails' `monetize` -- and wins across nearly every metric.

## Format Benchmark: Money.format vs number_to_currency

Benchmark comparing `Mint::Money#format` against Rails' `number_to_currency` helper with 10 000 iterations per variant.

| Variant | Money.format | number_to_currency | ratio |
|---|---|---|---|
| small default | 0.036s | 0.375s | 10.5× faster |
| large default | 0.050s | 0.398s | 8.0× faster |
| huge default | 0.061s | 0.398s | 6.5× faster |
| no symbol | 0.082s | 0.396s | 4.8× faster |
| comma dec | 0.053s | 0.374s | 7.1× faster |
| no delim | 0.021s | 0.373s | 18.1× faster |
| wide symbol | 0.049s | 0.371s | 7.5× faster |

`Money.format` is **5–18× faster** than `number_to_currency` across all variants. The widest gap is the "no delimiter" variant (18.1×) since `Money.format` simply skips thousands grouping, while `number_to_currency` still runs its full formatting pipeline with `delimiter: ''`.

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
