# frozen_string_literal: true

require 'test_helper'

class PluckAmountTest < ActiveSupport::TestCase
  test 'pluck_amount returns money objects for composite attributes' do
    Offer.create!(price: 30.dollars)
    Offer.create!(price: 10.euros)
    Offer.create!(price: 20.euros)

    amounts = Offer.order_by_amount(price: :asc).pluck_amount(:price)

    assert_equal [10.euros, 20.euros, 30.dollars], amounts
  end

  test 'pluck_amount works for single-column attributes' do
    SimpleOffer.create!(price: 100.reais)
    SimpleOffer.create!(price: 10.reais)
    SimpleOffer.create!(price: 50.reais)

    amounts = SimpleOffer.order_by_amount(price: :asc).pluck_amount(:price)

    assert_equal [10.reais, 50.reais, 100.reais], amounts
  end

  test 'pluck_amount returns an empty array when there are no records' do
    assert_equal [], Offer.pluck_amount(:price)
  end

  test 'pluck_amount raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.pluck_amount(:product) }
  end
end
