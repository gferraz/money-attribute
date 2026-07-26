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
end
# rubocop:enable Lint/AmbiguousRange
