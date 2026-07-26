# frozen_string_literal: true

require 'test_helper'

class WhereCurrencyTest < ActiveSupport::TestCase
  test 'where_currency filters by currency code' do
    eur = Offer.create!(price: 10.euros)
    Offer.create!(price: 10.dollars)

    assert_equal [eur], Offer.where_currency(price: 'EUR')
  end

  test 'where_currency works with Money object' do
    eur = Offer.create!(price: 10.euros)
    Offer.create!(price: 10.dollars)

    assert_equal [eur], Offer.where_currency(price: 50.euros)
  end

  test 'where_currency returns all records for any currency' do
    eur = Offer.create!(price: 10.euros)
    usd = Offer.create!(price: 10.dollars)

    assert_equal [eur], Offer.where_currency(price: 'EUR')
    assert_equal [usd], Offer.where_currency(price: 'USD')
  end

  test 'where_currency generates correct SQL' do
    sql = Offer.where_currency(price: 'EUR').to_sql

    assert_includes sql, 'price_currency'
    assert_includes sql, 'EUR'
    assert_not_includes sql, 'price_amount'
  end

  test 'where_currency raises on single-column attribute' do
    assert_raises(ArgumentError) { SimpleOffer.where_currency(price: 'BRL') }
  end

  test 'where_currency raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.where_currency(product: 'Widget') }
  end
end
