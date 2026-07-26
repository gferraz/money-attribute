# frozen_string_literal: true

# rubocop:disable Lint/AmbiguousRange
require 'test_helper'

class QueryChainingTest < ActiveSupport::TestCase
  test 'where_money chains with order_by_amount' do
    Offer.create!(price: 10.euros)
    Offer.create!(price: 50.euros)
    Offer.create!(price: 100.euros)
    Offer.create!(price: 30.dollars)

    amounts = Offer.where_money(price: 10.euros..100.euros)
                   .order_by_amount(price: :desc)
                   .pluck(:price_amount)

    assert_equal [100, 50, 10], amounts
  end

  test 'where_currency chains with order_by_amount' do
    eur1 = Offer.create!(price: 10.euros)
    eur2 = Offer.create!(price: 50.euros)
    Offer.create!(price: 30.dollars)

    prices = Offer.where_currency(price: 'EUR').order_by_amount(price: :desc)

    assert_equal [eur2, eur1], prices
  end

  test 'where_amount chains with order_by_amount' do
    eur1 = Offer.create!(price: 10.euros)
    eur2 = Offer.create!(price: 50.euros)
    usd = Offer.create!(price: 100.dollars)

    assert_equal [eur1, eur2, usd], Offer.where_amount(price: 10..100).order_by_amount(price: :asc).to_a
  end

  test 'where_currency and where_amount chain together' do
    eur_low = Offer.create!(price: 10.euros)
    Offer.create!(price: 100.euros)
    Offer.create!(price: 50.dollars)

    results = Offer.where_currency(price: 'EUR')
                   .where_amount(price: 10..50)
                   .order_by_amount(price: :asc)

    assert_equal [eur_low], results.to_a
  end
end
# rubocop:enable Lint/AmbiguousRange
