# frozen_string_literal: true

# rubocop:disable Lint/AmbiguousRange
require 'test_helper'

class WhereMoneySingleTest < ActiveSupport::TestCase
  test 'where_money with range queries single-column attribute' do
    low = SimpleOffer.create!(price: 10.reais)
    mid = SimpleOffer.create!(price: 50.reais)
    high = SimpleOffer.create!(price: 100.reais)

    assert_equal [low, mid, high], SimpleOffer.where_money(price: 10.reais..100.reais)
  end

  test 'where_money with range excludes outside values for single-column' do
    inside = SimpleOffer.create!(price: 50.reais)
    SimpleOffer.create!(price: 5.reais)
    SimpleOffer.create!(price: 200.reais)

    assert_equal [inside], SimpleOffer.where_money(price: 10.reais..100.reais)
  end

  test 'where_money with single money queries single-column attribute' do
    offer = SimpleOffer.create!(price: 15.reais)

    assert_equal [offer], SimpleOffer.where_money(price: 15.reais)
  end

  test 'where_money with array queries single-column attribute' do
    a = SimpleOffer.create!(price: 10.reais)
    SimpleOffer.create!(price: 20.reais)
    c = SimpleOffer.create!(price: 30.reais)

    assert_equal [a, c], SimpleOffer.where_money(price: [10.reais, 30.reais])
  end
end
# rubocop:enable Lint/AmbiguousRange
