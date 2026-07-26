# frozen_string_literal: true

require 'test_helper'

class PickAmountTest < ActiveSupport::TestCase
  test 'pick_amount returns first money value for composite attributes' do
    Offer.create!(price: 30.dollars)
    Offer.create!(price: 10.euros)
    Offer.create!(price: 20.euros)

    amount = Offer.order_by_amount(price: :asc).pick_amount(:price)

    assert_equal 10.euros, amount
  end

  test 'pick_amount works for single-column attributes' do
    SimpleOffer.create!(price: 100.reais)
    SimpleOffer.create!(price: 10.reais)
    SimpleOffer.create!(price: 50.reais)

    amount = SimpleOffer.order_by_amount(price: :asc).pick_amount(:price)

    assert_equal 10.reais, amount
  end

  test 'pick_amount returns array for multiple attributes' do
    transaction = FinancialTransaction.create!(
      amount: 100.dollars,
      discount: 20.euros,
      tax: 50,
      price: 15.50.dollars,
      total: 99.99.euros
    )

    result = FinancialTransaction.where(id: transaction.id).pick_amount(:amount, :discount, :tax)

    assert_equal [100.dollars, 20.euros, 50.to_money], result
  end

  test 'pick_amount returns nil when there are no records' do
    assert_nil Offer.pick_amount(:price)
  end

  test 'pick_amount raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.pick_amount(:product) }
  end
end
