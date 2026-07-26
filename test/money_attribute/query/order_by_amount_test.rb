# frozen_string_literal: true

require 'test_helper'

class OrderByAmountTest < ActiveSupport::TestCase
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

  test 'order_by_amount generates correct SQL for composite' do
    sql = Offer.order_by_amount(price: :desc).to_sql

    assert_includes sql, 'ORDER BY'
    assert_includes sql, 'price_currency'
    assert_includes sql, 'price_amount'
    assert_includes sql, 'DESC'
  end

  test 'order_by_amount raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.order_by_amount(product: :asc) }
  end
end
