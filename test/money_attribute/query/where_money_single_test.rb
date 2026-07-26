# frozen_string_literal: true

# rubocop:disable Lint/AmbiguousRange
require 'test_helper'

class WhereMoneySingleTest < ActiveSupport::TestCase
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

  test 'where_money with single money queries single-column attribute' do
    offer = SimpleOffer.create!(price: 15.to_money('BRL'))

    results = SimpleOffer.where_money(price: 15.to_money('BRL'))

    assert_equal 1, results.count
    assert_equal offer, results.first
  end

  test 'where_money with array queries single-column attribute' do
    a = SimpleOffer.create!(price: 10.to_money('BRL'))
    b = SimpleOffer.create!(price: 20.to_money('BRL'))
    c = SimpleOffer.create!(price: 30.to_money('BRL'))

    results = SimpleOffer.where_money(price: [10.to_money('BRL'), 30.to_money('BRL')])

    assert_includes results, a
    assert_not_includes results, b
    assert_includes results, c
  end
end
# rubocop:enable Lint/AmbiguousRange
