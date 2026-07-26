# frozen_string_literal: true

require 'test_helper'

class WhereAmountTest < ActiveSupport::TestCase
  test 'where_amount filters by amount regardless of currency' do
    eur = Offer.create!(price: 10.euros)
    usd = Offer.create!(price: 10.dollars)
    Offer.create!(price: 20.euros)

    results = Offer.where_amount(price: 10)

    assert_includes results, eur
    assert_includes results, usd
    assert_equal 2, results.count
  end

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

  test 'where_amount with array queries by amount' do
    a = Offer.create!(price: 10.euros)
    b = Offer.create!(price: 20.dollars)
    c = Offer.create!(price: 30.euros)

    results = Offer.where_amount(price: [10, 30])

    assert_includes results, a
    assert_not_includes results, b
    assert_includes results, c
  end

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

  test 'where_amount raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.where_amount(product: 'Widget') }
  end

  test 'where_amount generates correct SQL for composite' do
    sql = Offer.where_amount(price: 10..100).to_sql

    assert_includes sql, 'price_amount'
    assert_includes sql, 'BETWEEN'
    assert_not_includes sql, 'price_currency'
  end
end
