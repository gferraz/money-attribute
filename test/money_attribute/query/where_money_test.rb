# frozen_string_literal: true

# rubocop:disable Lint/AmbiguousRange
require 'test_helper'

class WhereMoneyCompositeTest < ActiveSupport::TestCase
  test 'where_money with range queries composite attribute' do
    low = Offer.create!(price: 10.euros)
    mid = Offer.create!(price: 50.euros)
    high = Offer.create!(price: 100.euros)

    assert_equal [low, mid, high], Offer.where_money(price: 10.euros..100.euros)
  end

  test 'where_money with range excludes outside values' do
    inside = Offer.create!(price: 50.euros)
    Offer.create!(price: 5.euros)
    Offer.create!(price: 200.euros)

    assert_equal [inside], Offer.where_money(price: 10.euros..100.euros)
  end

  test 'where_money with exclusive range excludes upper bound' do
    lower = Offer.create!(price: 10.euros)
    Offer.create!(price: 100.euros)

    assert_equal [lower], Offer.where_money(price: 10.euros...100.euros)
  end

  test 'where_money with range filters by currency' do
    eur = Offer.create!(price: 50.euros)
    Offer.create!(price: 50.dollars)

    assert_equal [eur], Offer.where_money(price: 10.euros..100.euros)
  end

  test 'where_money with range raises on currency mismatch' do
    assert_raises(TypeError) { Offer.where_money(price: 10.euros..100.dollars) }
  end

  test 'where_money with single money queries composite attribute' do
    offer = Offer.create!(price: 15.euros)

    assert_equal [offer], Offer.where_money(price: 15.euros)
  end

  test 'where_money with single money excludes different currency' do
    Offer.create!(price: 15.euros)

    assert_empty Offer.where_money(price: 15.dollars)
  end

  test 'where_money with array queries composite attribute' do
    a = Offer.create!(price: 10.euros)
    Offer.create!(price: 20.euros)
    c = Offer.create!(price: 30.euros)

    assert_equal [a, c], Offer.where_money(price: [10.euros, 30.euros])
  end

  test 'where_money with array supports multiple currencies via OR' do
    eur = Offer.create!(price: 10.euros)
    usd = Offer.create!(price: 20.dollars)

    assert_equal [eur, usd], Offer.where_money(price: [10.euros, 20.dollars])
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
