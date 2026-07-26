# frozen_string_literal: true

require 'test_helper'

class WhereAmountTest < ActiveSupport::TestCase
  test 'where_amount filters by amount regardless of currency' do
    eur = Offer.create!(price: 10.euros)
    usd = Offer.create!(price: 10.dollars)
    Offer.create!(price: 20.euros)

    assert_equal [eur, usd], Offer.where_amount(price: 10)
  end

  test 'where_amount with range filters by amount range' do
    low = Offer.create!(price: 10.euros)
    mid = Offer.create!(price: 50.euros)
    high = Offer.create!(price: 100.euros)

    assert_equal [low, mid, high], Offer.where_amount(price: 10..100)
  end

  test 'where_amount with range crosses currencies' do
    eur = Offer.create!(price: 10.euros)
    usd = Offer.create!(price: 50.dollars)

    assert_equal [eur, usd], Offer.where_amount(price: 10..50)
  end

  test 'where_amount with exclusive range excludes upper bound' do
    lower = Offer.create!(price: 10.euros)
    Offer.create!(price: 100.euros)

    assert_equal [lower], Offer.where_amount(price: 10...100)
  end

  test 'where_amount with array queries by amount' do
    a = Offer.create!(price: 10.euros)
    Offer.create!(price: 20.dollars)
    c = Offer.create!(price: 30.euros)

    assert_equal [a, c], Offer.where_amount(price: [10, 30])
  end

  test 'where_amount queries single-column attribute' do
    SimpleOffer.create!(price: 10.reais)
    mid = SimpleOffer.create!(price: 50.reais)
    SimpleOffer.create!(price: 100.reais)

    assert_equal [mid], SimpleOffer.where_amount(price: 50)
  end

  test 'where_amount with range queries single-column attribute' do
    low = SimpleOffer.create!(price: 10.reais)
    mid = SimpleOffer.create!(price: 50.reais)
    high = SimpleOffer.create!(price: 100.reais)

    assert_equal [low, mid, high], SimpleOffer.where_amount(price: 10..100)
  end

  test 'where_amount raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.where_amount(product: 'Widget') }
  end

  test 'where_amount generates correct SQL for composite' do
    sql = Offer.where_amount(price: 10..100).to_sql

    assert_includes sql, '"offers"."price_amount" BETWEEN 10.0 AND 100.0'
  end
end
