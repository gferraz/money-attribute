# Benchmark Report: money_attribute vs plain Rails vs money-rails

Run at: 2026-07-30 00:29:40
Ruby 4.0.6, Rails 8.1.3.1

## Instantiation

| money_attribute (int) | money_attribute (dec) | money-rails | plain Rails | ma / plain |
|---|---|---|---|---|
| 0.04413 | 0.03475 | 0.05523 | 0.03073 | 1.4× |

## Create + save

| money_attribute (int) | money_attribute (dec) | money-rails | plain Rails | ma / plain |
|---|---|---|---|---|
| 0.68368 | 0.67341 | 1.01452 | 0.67137 | 1.0× |

## Update existing record

| money_attribute (int) | money_attribute (dec) | money-rails | plain Rails | ma / plain |
|---|---|---|---|---|
| 0.67098 | 0.68792 | 1.04914 | 0.67792 | 1.0× |

## Setter only (no DB write)

| money_attribute (int) | money_attribute (dec) | money-rails | plain Rails | ma / plain |
|---|---|---|---|---|
| 0.00960 | 0.01048 | 0.01564 | 0.00201 | 4.8× |

## Read from cached record

| money_attribute (int) | money_attribute (dec) | money-rails | plain Rails | ma / plain |
|---|---|---|---|---|
| 0.00047 | 0.00044 | 0.01797 | 0.00087 | 0.5× |

## Query by raw columns

| money_attribute (int) | money_attribute (dec) | money-rails | plain Rails | ma / plain |
|---|---|---|---|---|
| 0.18780 | 0.17978 | 0.22688 | 0.19230 | 1.0× |

## Query by Money object (composed_of decomposition)

Only money_attribute supports this — money-rails cannot decompose `Money` in WHERE clauses.

| Variant | money_attribute |
|---|---|
| integer column | 0.40711 |
| decimal column | 0.41973 |

## SQL generation (.to_sql)

| money_attribute (int) | money_attribute (dec) | money-rails | plain Rails | ma / plain |
|---|---|---|---|---|
| 0.19275 | 0.18560 | 0.21115 | 0.19012 | 1.0× |

## Multi-record query (100 records × 1000 iters)

| money_attribute (int) | money_attribute (dec) | money-rails | plain Rails | ma / plain |
|---|---|---|---|---|
| 9.64771 | 12.87086 | 13.59132 | 4.54974 | 2.1× |

## Arithmetic

| Variant | money_attribute |
|---|---|
| integer column | 0.01116 |

## Query helpers

| Benchmark | money_attribute | plain Rails | ma / plain |
|---|---|---|---|
| where_amount (hash scalar) | 0.02531 | 0.05445 | 0.5× |
| where_amount (hash Range) | 0.03578 | 0.08486 | 0.4× |
| where_amount (hash Array) | 0.03523 | 0.05531 | 0.6× |
| where_amount (String <) | 0.05558 | 0.01636 | 3.4× |
| where_amount (String AND) | 0.07844 | 0.01790 | 4.4× |
| where_amount (String NOT) | 0.05674 | 0.01582 | 3.6× |
| where_amount (String IS NULL) | 0.05400 | 0.01538 | 3.5× |
| where_currency | 0.04174 | 0.03597 | 1.2× |
| order_by_amount (desc) | 1.27681 | 1.10863 | 1.2× |
| pluck_amount single | 1.07679 | 0.30079 | 3.6× |
| pick_amount single | 0.26205 | 0.20497 | 1.3× |
| sum_amount | 0.46077 | 0.43034 | 1.1× |

## Caching

| Property | money_attribute (int) | money_attribute (dec) | money-rails | plain Rails (int) | plain Rails (dec) |
|---|---|---|---|---|---|
| Same object on repeated read? | true | true | true | true | true |
| Repeated read ×5000 | 0.00042 | 0.00042 | 0.01785 | 0.00085 | 0.00084 |
| Objects allocated (×5000 reads) | 2 | 2 | 85002 | 2 | 2 |

## Format benchmark: Money.format vs number_to_currency

10 000 iterations per variant.

| Variant | Money.format | number_to_currency | ratio |
|---|---|---|---|
| small default | 0.03310 | 0.34585 | 10.4× faster |
| large default | 0.04810 | 0.35047 | 7.3× faster |
| huge default | 0.05322 | 0.35199 | 6.6× faster |
| no symbol | 0.04378 | 0.35977 | 8.2× faster |
| comma dec | 0.04948 | 0.36810 | 7.4× faster |
| no delim | 0.01822 | 0.36673 | 20.1× faster |
| wide symbol | 0.04552 | 0.36704 | 8.1× faster |

## Scaling: Mass insert

| Size | money_attribute (int) | money_attribute (dec) | money-rails | plain Rails (int) | ma / plain |
|---|---|---|---|---|---|
| 20 | 0.0019 | 0.0020 | 0.0030 | 0.0017 | 1.1× |
| 200 | 0.0164 | 0.0156 | 0.0289 | 0.0153 | 1.1× |
| 2000 | 0.1797 | 0.1653 | 0.2857 | 0.1686 | 1.1× |
| 20000 | 1.6667 | 1.6120 | 3.0503 | 1.7254 | 1.0× |

## Scaling: Bulk update

| Size | money_attribute (int) | money_attribute (dec) | money-rails | plain Rails (int) | ma / plain |
|---|---|---|---|---|---|
| 20 | 0.0030 | 0.0035 | 0.0050 | 0.0027 | 1.1× |
| 200 | 0.0256 | 0.0316 | 0.0375 | 0.0255 | 1.0× |
| 2000 | 0.2891 | 0.3011 | 0.4303 | 0.2940 | 1.0× |
| 20000 | 2.8881 | 3.0722 | 4.2167 | 2.9238 | 1.0× |

## Environment

- Ruby: 4.0.6
- Rails: 8.1.3.1
- SQLite3
- 5000 iterations per test (unless noted)
- money_attribute and money-rails pass a Money object through the attribute setter
- plain Rails passes raw column values (subunits for int, BigDecimal for dec)
- Each side runs in a separate process (no gem conflict)
- Minimal environment (no full Rails app boot)
