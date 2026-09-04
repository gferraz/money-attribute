# Performance Roadmap

## Priorities

### 1. Optimize String `where_amount` Queries

**Priority:** High
**Status:** Implemented

**Location:** `lib/money_attribute/query/amount_condition.rb:39-48`

String-based `where_amount` queries repeatedly scan and transform the SQL:

- Validate identifiers.
- Find every `?` placeholder.
- Rescan the SQL before each placeholder.
- Rebuild replacement hashes and regular expressions.

The current profiler shows significant garbage collection and identifies
`substitute_attribute_names` as the largest Ruby-level frame for this path.
Existing benchmarks show string queries are approximately 3.4-4.4x slower than
equivalent plain SQL.

**Approach:** Parse each SQL template once and cache a compiled query plan by
model and SQL template. The plan should retain the substituted SQL and the
attribute specs needed to decompose bind values.

**Measured result:** The focused before/after benchmark improved relation
construction by approximately 51% for one condition, 64% for the common
two-condition template, and 79% for an eight-condition expression. Result
loading and allocation benchmarks were unchanged within normal run-to-run
noise.

### 2. Cache SQL Substitution Metadata

**Priority:** High

**Location:** `lib/money_attribute/query/amount_condition.rb:189-205`

`specs_to_substitute`, the lookup hash, and the replacement regexp are rebuilt
for every string query. The attribute registry already caches the registered
attribute name pattern and can be extended to cache substitution metadata.

Cache the following per model:

- Attribute-to-column lookup.
- Substitution regular expression.
- Any compiled string-query metadata.

This is a low-risk optimization for repeated query workloads.

### 3. Replace Repeated Placeholder Scans

**Priority:** Medium
**Status:** Implemented

**Location:** `lib/money_attribute/query/amount_condition.rb:147-153`

`spec_at_position` creates a substring and scans all preceding attribute
references for each placeholder. This can become quadratic as expressions grow
or contain more placeholders.

**Approach:** Use a single left-to-right pass that validates identifiers,
substitutes amount columns, and associates each placeholder with its nearest
attribute spec.

**Measured result:** The cache-independent parser benchmark compares the new
single-pass parser with the previous multi-scan algorithm on identical SQL.
The single-pass implementation was approximately 3.2x faster for eight
conditions and 6.3x faster for 32 conditions. The focused benchmark now also
includes cold queries with the plan cache cleared per call.

### 4. Cache Currency Resolution During Result Reconstruction

**Priority:** Medium

**Location:** `lib/money_attribute/query/pluck.rb:36`

Composite `pluck_amount` reconstructs a `Mint::Money` value for every row.
Currency metadata may be resolved repeatedly when many rows share the same
currency.

**Approach:** Use a short-lived per-query cache keyed by currency code while
reconstructing composite results. Preserve the existing behavior for missing or
default currencies.

The current profile shows database execution dominates `pluck_amount`, so this
optimization matters most for large result sets or low-latency databases.

### 5. Validate Production Query Plans and Add Indexes

**Priority:** Medium

Money-aware helpers query the backing amount and currency columns directly.
Indexing is therefore likely to have a larger production impact than Ruby-level
micro-optimizations.

Potential application-level indexes include:

- `(price_currency, price_amount)` for currency-filtered ordering.
- `(price_amount, price_currency)` for amount-first filtering.
- Currency-column indexes for grouped sums.

The migration helpers should remain index-neutral because the best index layout
depends on application query patterns.

### 6. Fix Derived Registry Cache Invalidation

**Priority:** Low, with correctness implications
**Status:** Implemented

**Location:** `lib/money_attribute/attribute_spec_registry.rb:58-74`

`money_attribute_names_set` and `money_attribute_name_pattern` are cached
independently from later registrations. If either cache is populated before a
new macro declaration on the same model, derived metadata can become stale.

Invalidate or replace the derived caches whenever
`register_money_attribute_spec` adds or replaces a spec. The same registry
metadata cache can then support the string-query optimizations above.

Regression tests now verify that late registrations refresh the derived name
set and name pattern, and that re-registering an attribute clears compiled
query plans.

## Already Performing Well

- Cached composite reads are effectively optimal; existing benchmarks report two
  allocations across 5,000 repeated reads.
- Assignment, persistence, and arithmetic are competitive with or faster than
  the compared alternatives.
- Hash-based `where_amount` queries are already efficient.
- `pluck_amount` and `order_by_amount` are primarily database/result-size bound
  in the current profiles.

## Validation Plan

For each optimization:

1. Add or update focused tests preserving SQL substitution, bind decomposition,
   and query chaining behavior.
2. Benchmark before and after with the existing query-helper benchmark.
3. Profile `string_query`, `pluck`, and `multi_record` modes.
4. Run the complete test suite and RuboCop.
5. Compare query plans with representative PostgreSQL, MySQL, and SQLite data
   volumes before recommending indexes.

The focused benchmark command is `bundle exec rake bench:performance`. It
measures string-query scaling, repeated versus varying SQL templates, pluck
result-set size, currency cardinality, allocations, and indexed versus
unindexed lookups. The existing `bundle exec rake bench` remains the broad
cross-gem comparison.

## Measuring Real Gains

Capture a baseline before each optimization:

```sh
PERFORMANCE_OUTPUT=tmp/performance-before.json bundle exec rake bench:performance
```

Run the same command after the change with a different output path, then
compare the results:

```sh
PERFORMANCE_OUTPUT=tmp/performance-after.json bundle exec rake bench:performance
BASELINE=tmp/performance-before.json CURRENT=tmp/performance-after.json \
  PERFORMANCE_REPORT=tmp/performance-comparison.md \
  bundle exec rake bench:performance:compare
```

The comparison reports percentage improvement for elapsed time and allocated
objects to the terminal and writes a human-readable Markdown report. Positive
percentages mean the current implementation is faster or allocates fewer
objects. Run each side several times and compare stable runs; do not treat a
single noisy run as proof of a gain.

## Suggested Implementation Order

1. Cache SQL substitution and parsing metadata.
2. Replace repeated placeholder scans with a single-pass parser.
3. Add currency resolution caching for composite result reconstruction.
4. Fix registry cache invalidation as part of the metadata-cache work.
5. Validate production query plans and add application-level indexes.
