# frozen_string_literal: true

# rubocop:disable Lint/AmbiguousRange
require 'test_helper'

class QueryTest < ActiveSupport::TestCase
  # where_money — Composite Range

  test 'where_money with range queries composite attribute' do
    low = Offer.create!(price: 10.euros)
    mid = Offer.create!(price: 50.euros)
    high = Offer.create!(price: 100.euros)

    results = Offer.where_money(price: 10.euros..100.euros)

    assert_includes results, low
    assert_includes results, mid
    assert_includes results, high
  end

  test 'where_money with range excludes outside values' do
    inside = Offer.create!(price: 50.euros)
    Offer.create!(price: 5.euros)
    Offer.create!(price: 200.euros)

    results = Offer.where_money(price: 10.euros..100.euros)

    assert_includes results, inside
    assert_equal 1, results.count
  end

  test 'where_money with exclusive range excludes upper bound' do
    lower = Offer.create!(price: 10.euros)
    upper = Offer.create!(price: 100.euros)

    results = Offer.where_money(price: 10.euros...100.euros)

    assert_includes results, lower
    assert_not_includes results, upper
  end

  test 'where_money with range filters by currency' do
    eur = Offer.create!(price: 50.euros)
    usd = Offer.create!(price: 50.dollars)

    results = Offer.where_money(price: 10.euros..100.euros)

    assert_includes results, eur
    assert_not_includes results, usd
  end

  test 'where_money with range raises on currency mismatch' do
    assert_raises(TypeError) { Offer.where_money(price: 10.euros..100.dollars) }
  end

  # where_money — Composite single value

  test 'where_money with single money queries composite attribute' do
    offer = Offer.create!(price: 15.euros)

    results = Offer.where_money(price: 15.euros)

    assert_equal 1, results.count
    assert_equal offer, results.first
  end

  test 'where_money with single money excludes different currency' do
    Offer.create!(price: 15.euros)

    results = Offer.where_money(price: 15.dollars)

    assert_empty results
  end

  # where_money — Composite array

  test 'where_money with array queries composite attribute' do
    a = Offer.create!(price: 10.euros)
    b = Offer.create!(price: 20.euros)
    c = Offer.create!(price: 30.euros)

    results = Offer.where_money(price: [10.euros, 30.euros])

    assert_includes results, a
    assert_not_includes results, b
    assert_includes results, c
  end

  test 'where_money with array supports multiple currencies via OR' do
    eur = Offer.create!(price: 10.euros)
    usd = Offer.create!(price: 20.dollars)

    results = Offer.where_money(price: [10.euros, 20.dollars])

    assert_includes results, eur
    assert_includes results, usd
  end

  # where_money — Single-column Range

  test 'where_money with range queries single-column attribute' do
    low = SimpleOffer.create!(price: 10.to_money('BRL'))
    mid = SimpleOffer.create!(price: 50.to_money('BRL'))
    high = SimpleOffer.create!(price: 100.to_money('BRL'))

    results = SimpleOffer.where_money(price: 10.to_money('BRL')..100.to_money('BRL'))

    assert_includes results, low
    assert_includes results, mid
    assert_includes results, high
  end

  test 'where_money with range excludes outside values for single-column' do
    inside = SimpleOffer.create!(price: 50.to_money('BRL'))
    SimpleOffer.create!(price: 5.to_money('BRL'))
    SimpleOffer.create!(price: 200.to_money('BRL'))

    results = SimpleOffer.where_money(price: 10.to_money('BRL')..100.to_money('BRL'))

    assert_includes results, inside
    assert_equal 1, results.count
  end

  # where_money — Single-column single value

  test 'where_money with single money queries single-column attribute' do
    offer = SimpleOffer.create!(price: 15.to_money('BRL'))

    results = SimpleOffer.where_money(price: 15.to_money('BRL'))

    assert_equal 1, results.count
    assert_equal offer, results.first
  end

  # where_money — Single-column array

  test 'where_money with array queries single-column attribute' do
    a = SimpleOffer.create!(price: 10.to_money('BRL'))
    b = SimpleOffer.create!(price: 20.to_money('BRL'))
    c = SimpleOffer.create!(price: 30.to_money('BRL'))

    results = SimpleOffer.where_money(price: [10.to_money('BRL'), 30.to_money('BRL')])

    assert_includes results, a
    assert_not_includes results, b
    assert_includes results, c
  end

  # where_money — Error handling

  test 'where_money raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.where_money(product: 'Widget') }
  end

  # where_money — SQL generation

  test 'where_money generates correct SQL for composite range' do
    sql = Offer.where_money(price: 10.euros..100.euros).to_sql

    assert_includes sql, 'price_amount'
    assert_includes sql, 'price_currency'
    assert_includes sql, 'BETWEEN'
    assert_includes sql, 'EUR'
  end

  # where_currency — Composite

  test 'where_currency filters by currency code' do
    eur = Offer.create!(price: 10.euros)
    usd = Offer.create!(price: 10.dollars)

    results = Offer.where_currency(price: 'EUR')

    assert_includes results, eur
    assert_not_includes results, usd
  end

  test 'where_currency works with Money object' do
    eur = Offer.create!(price: 10.euros)
    usd = Offer.create!(price: 10.dollars)

    results = Offer.where_currency(price: 50.euros)

    assert_includes results, eur
    assert_not_includes results, usd
  end

  test 'where_currency returns all records for any currency' do
    eur = Offer.create!(price: 10.euros)
    usd = Offer.create!(price: 10.dollars)

    eur_all = Offer.where_currency(price: 'EUR')
    usd_all = Offer.where_currency(price: 'USD')

    assert_includes eur_all, eur
    assert_not_includes eur_all, usd
    assert_includes usd_all, usd
    assert_not_includes usd_all, eur
  end

  test 'where_currency generates correct SQL' do
    sql = Offer.where_currency(price: 'EUR').to_sql

    assert_includes sql, 'price_currency'
    assert_includes sql, 'EUR'
    assert_not_includes sql, 'price_amount'
  end

  # where_currency — Single-column raises

  test 'where_currency raises on single-column attribute' do
    assert_raises(ArgumentError) { SimpleOffer.where_currency(price: 'BRL') }
  end

  # where_currency — Non-money raises

  test 'where_currency raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.where_currency(product: 'Widget') }
  end

  # where_amount — Composite equality

  test 'where_amount filters by amount regardless of currency' do
    eur = Offer.create!(price: 10.euros)
    usd = Offer.create!(price: 10.dollars)
    Offer.create!(price: 20.euros)

    results = Offer.where_amount(price: 10)

    assert_includes results, eur
    assert_includes results, usd
    assert_equal 2, results.count
  end

  # where_amount — Composite range

  test 'where_amount with range filters by amount range' do
    low = Offer.create!(price: 10.euros)
    mid = Offer.create!(price: 50.euros)
    high = Offer.create!(price: 100.euros)

    results = Offer.where_amount(price: 10..100)

    assert_includes results, low
    assert_includes results, mid
    assert_includes results, high
  end

  test 'where_amount with range crosses currencies' do
    eur = Offer.create!(price: 10.euros)
    usd = Offer.create!(price: 50.dollars)

    results = Offer.where_amount(price: 10..50)

    assert_includes results, eur
    assert_includes results, usd
  end

  test 'where_amount with exclusive range excludes upper bound' do
    lower = Offer.create!(price: 10.euros)
    upper = Offer.create!(price: 100.euros)

    results = Offer.where_amount(price: 10...100)

    assert_includes results, lower
    assert_not_includes results, upper
  end

  # where_amount — Composite array

  test 'where_amount with array queries by amount' do
    a = Offer.create!(price: 10.euros)
    b = Offer.create!(price: 20.dollars)
    c = Offer.create!(price: 30.euros)

    results = Offer.where_amount(price: [10, 30])

    assert_includes results, a
    assert_not_includes results, b
    assert_includes results, c
  end

  # where_amount — Single-column

  test 'where_amount queries single-column attribute' do
    _low = SimpleOffer.create!(price: 10.to_money('BRL'))
    mid = SimpleOffer.create!(price: 50.to_money('BRL'))
    _high = SimpleOffer.create!(price: 100.to_money('BRL'))

    results = SimpleOffer.where_amount(price: 50)

    assert_equal 1, results.count
    assert_equal mid, results.first
  end

  test 'where_amount with range queries single-column attribute' do
    low = SimpleOffer.create!(price: 10.to_money('BRL'))
    mid = SimpleOffer.create!(price: 50.to_money('BRL'))
    high = SimpleOffer.create!(price: 100.to_money('BRL'))

    results = SimpleOffer.where_amount(price: 10..100)

    assert_includes results, low
    assert_includes results, mid
    assert_includes results, high
  end

  # where_amount — Error handling

  test 'where_amount raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.where_amount(product: 'Widget') }
  end

  # where_amount — SQL generation

  test 'where_amount generates correct SQL for composite' do
    sql = Offer.where_amount(price: 10..100).to_sql

    assert_includes sql, 'price_amount'
    assert_includes sql, 'BETWEEN'
    assert_not_includes sql, 'price_currency'
  end

  # order_by_amount — Composite (currency ASC, amount direction)

  test 'order_by_amount orders by currency then amount ascending' do
    eur1 = Offer.create!(price: 100.euros)
    eur2 = Offer.create!(price: 10.euros)
    usd1 = Offer.create!(price: 50.dollars)

    results = Offer.order_by_amount(price: :asc)

    assert_equal [eur2, eur1, usd1], results.to_a
  end

  test 'order_by_amount orders by currency then amount descending' do
    eur1 = Offer.create!(price: 10.euros)
    eur2 = Offer.create!(price: 100.euros)
    usd1 = Offer.create!(price: 50.dollars)

    results = Offer.order_by_amount(price: :desc)

    assert_equal [eur2, eur1, usd1], results.to_a
  end

  test 'order_by_amount defaults to ascending' do
    eur1 = Offer.create!(price: 10.euros)
    eur2 = Offer.create!(price: 100.euros)

    results = Offer.order_by_amount(price: nil)

    assert_equal [eur1, eur2], results.to_a
  end

  # order_by_amount — Single-column

  test 'order_by_amount orders single-column attribute ascending' do
    SimpleOffer.create!(price: 100.to_money('BRL'))
    SimpleOffer.create!(price: 10.to_money('BRL'))
    SimpleOffer.create!(price: 50.to_money('BRL'))

    amounts = SimpleOffer.order_by_amount(price: :asc).map { |o| o.price.to_d }

    assert_equal [BigDecimal('10.0'), BigDecimal('50.0'), BigDecimal('100.0')], amounts
  end

  test 'order_by_amount orders single-column attribute descending' do
    SimpleOffer.create!(price: 10.to_money('BRL'))
    SimpleOffer.create!(price: 100.to_money('BRL'))
    SimpleOffer.create!(price: 50.to_money('BRL'))

    amounts = SimpleOffer.order_by_amount(price: :desc).map { |o| o.price.to_d }

    assert_equal [BigDecimal('100.0'), BigDecimal('50.0'), BigDecimal('10.0')], amounts
  end

  # order_by_amount — SQL

  test 'order_by_amount generates correct SQL for composite' do
    sql = Offer.order_by_amount(price: :desc).to_sql

    assert_includes sql, 'ORDER BY'
    assert_includes sql, 'price_currency'
    assert_includes sql, 'price_amount'
    assert_includes sql, 'DESC'
  end

  # order_by_amount — Error handling

  test 'order_by_amount raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.order_by_amount(product: :asc) }
  end

  # Combining helpers

  test 'where_money chains with order_by_amount' do
    Offer.create!(price: 10.euros)
    Offer.create!(price: 50.euros)
    Offer.create!(price: 100.euros)
    Offer.create!(price: 30.dollars)

    amounts = Offer.where_money(price: 10.euros..100.euros)
                   .order_by_amount(price: :desc)
                   .map(&:price_amount)

    assert_equal [100.0, 50.0, 10.0], amounts
  end

  test 'where_currency chains with order_by_amount' do
    eur1 = Offer.create!(price: 10.euros)
    eur2 = Offer.create!(price: 50.euros)
    Offer.create!(price: 30.dollars)

    amounts = Offer.where_currency(price: 'EUR')
                   .order_by_amount(price: :desc)
                   .map(&:price_amount)

    assert_equal [50.0, 10.0], amounts
    assert_includes amounts, eur1.price_amount
    assert_includes amounts, eur2.price_amount
  end

  test 'where_amount chains with order_by_amount' do
    eur1 = Offer.create!(price: 10.euros)
    eur2 = Offer.create!(price: 50.euros)
    usd = Offer.create!(price: 100.dollars)

    results = Offer.where_amount(price: 10..100)
                   .order_by_amount(price: :asc)

    # Currency ASC: EUR before USD, then amount ASC within each
    assert_equal [eur1, eur2, usd], results.to_a
  end

  test 'where_currency and where_amount chain together' do
    eur_low = Offer.create!(price: 10.euros)
    eur_high = Offer.create!(price: 100.euros)
    usd_mid = Offer.create!(price: 50.dollars)

    results = Offer.where_currency(price: 'EUR')
                   .where_amount(price: 10..50)
                   .order_by_amount(price: :asc)

    assert_equal [eur_low], results.to_a
    assert_not_includes results, eur_high
    assert_not_includes results, usd_mid
  end

  # sum_amount — Composite (decimal column)

  test 'sum_amount returns Hash when multiple currencies exist' do
    Offer.create!(price: 10.euros)
    Offer.create!(price: 20.euros)
    Offer.create!(price: 30.dollars)
    Offer.create!(price: 40.dollars)

    sum = Offer.sum_amount(:price)

    assert_instance_of Hash, sum
    assert_equal %w[EUR USD], sum.keys.sort
    assert_equal 30.euros, sum['EUR']
    assert_equal 70.dollars, sum['USD']
  end

  test 'sum_amount returns single Money when scoped to one currency' do
    Offer.create!(price: 10.euros)
    Offer.create!(price: 20.euros)
    Offer.create!(price: 30.dollars)

    result = Offer.where_currency(price: 'EUR').sum_amount(:price)

    assert_instance_of Mint::Money, result
    assert_equal BigDecimal('30'), result.to_d
    assert_equal 'EUR', result.currency_code
  end

  test 'sum_amount returns single Money when all rows share one currency' do
    Offer.create!(price: 10.euros)
    Offer.create!(price: 20.euros)

    result = Offer.sum_amount(:price)

    assert_instance_of Mint::Money, result
    assert_equal BigDecimal('30'), result.to_d
    assert_equal 'EUR', result.currency_code
  end

  # sum_amount — Single-column

  test 'sum_amount works for single-column attribute' do
    SimpleOffer.create!(price: 10.to_money('BRL'))
    SimpleOffer.create!(price: 20.to_money('BRL'))
    SimpleOffer.create!(price: 30.to_money('BRL'))

    result = SimpleOffer.sum_amount(:price)

    assert_instance_of Mint::Money, result
    assert_equal BigDecimal('60'), result.to_d
    assert_equal 'BRL', result.currency_code
  end

  # sum_amount — Integer column (subunits)

  test 'sum_amount handles integer (subunits) column' do
    FinancialTransaction.delete_all
    FinancialTransaction.create!(amount: Mint::Money.from_subunits(1000, 'USD'), currency: 'USD')
    FinancialTransaction.create!(amount: Mint::Money.from_subunits(2000, 'USD'), currency: 'USD')

    result = FinancialTransaction.sum_amount(:amount)

    assert_instance_of Mint::Money, result
    assert_equal 3000, result.subunits
    assert_equal 'USD', result.currency_code
  end

  # sum_amount — Multiple attributes

  test 'sum_amount with multiple attributes returns Hash' do
    FinancialTransaction.delete_all
    FinancialTransaction.create!(price_amount: 10, price_currency: 'EUR',
                                 discount: 5, discount_currency: 'EUR')

    result = FinancialTransaction.sum_amount(:price, :discount)

    assert_instance_of Hash, result
    assert_equal BigDecimal('10'), result[:price].to_d
    assert_equal BigDecimal('5'), result[:discount].to_d
  end

  # sum_amount — Empty result

  test 'sum_amount returns zero Money for empty result' do
    result = Offer.sum_amount(:price)

    assert_instance_of Mint::Money, result
    assert_equal 0, result
    assert_equal 'BRL', result.currency_code
  end

  # sum_amount — Error handling

  test 'sum_amount raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.sum_amount(:product) }
  end
end
# rubocop:enable Lint/AmbiguousRange
