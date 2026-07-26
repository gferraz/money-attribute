# frozen_string_literal: true

# rubocop:disable Lint/AmbiguousRange
require 'test_helper'

class WhereMoneyCompositeTest < ActiveSupport::TestCase
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

  test 'where_money raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.where_money(product: 'Widget') }
  end

  test 'where_money generates correct SQL for composite range' do
    sql = Offer.where_money(price: 10.euros..100.euros).to_sql

    assert_includes sql, 'price_amount'
    assert_includes sql, 'price_currency'
    assert_includes sql, 'BETWEEN'
    assert_includes sql, 'EUR'
  end
end
# rubocop:enable Lint/AmbiguousRange
