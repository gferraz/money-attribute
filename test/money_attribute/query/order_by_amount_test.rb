# frozen_string_literal: true

require 'test_helper'

class OrderByAmountTest < ActiveSupport::TestCase
  test 'order_by_amount orders by currency then amount ascending' do
    eur1 = Offer.create!(price: 100.euros)
    eur2 = Offer.create!(price: 10.euros)
    usd1 = Offer.create!(price: 50.dollars)

    assert_equal [eur2, eur1, usd1], Offer.order_by_amount(price: :asc).to_a
  end

  test 'order_by_amount orders by currency then amount descending' do
    eur1 = Offer.create!(price: 10.euros)
    eur2 = Offer.create!(price: 100.euros)
    usd1 = Offer.create!(price: 50.dollars)

    assert_equal [eur2, eur1, usd1], Offer.order_by_amount(price: :desc).to_a
  end

  test 'order_by_amount defaults to ascending' do
    eur1 = Offer.create!(price: 10.euros)
    eur2 = Offer.create!(price: 100.euros)

    assert_equal [eur1, eur2], Offer.order_by_amount(price: nil).to_a
  end

  test 'order_by_amount orders single-column attribute ascending' do
    SimpleOffer.create!(price: 100.reais)
    SimpleOffer.create!(price: 10.reais)
    SimpleOffer.create!(price: 50.reais)

    amounts = SimpleOffer.order_by_amount(price: :asc).pluck(:price)

    assert_equal [10.reais, 50.reais, 100.reais], amounts
  end

  test 'order_by_amount orders single-column attribute descending' do
    SimpleOffer.create!(price: 10.reais)
    SimpleOffer.create!(price: 100.reais)
    SimpleOffer.create!(price: 50.reais)

    amounts = SimpleOffer.order_by_amount(price: :desc).pluck(:price)

    assert_equal [100.reais, 50.reais, 10.reais], amounts
  end

  test 'order_by_amount generates correct SQL for composite' do
    sql = Offer.order_by_amount(price: :desc).to_sql

    assert_includes sql, 'ORDER BY "offers"."price_currency" ASC, "offers"."price_amount" DESC'
  end

  test 'order_by_amount raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.order_by_amount(product: :asc) }
  end
end
