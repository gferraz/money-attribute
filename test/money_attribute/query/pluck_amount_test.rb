# frozen_string_literal: true

require 'test_helper'

class PluckAmountTest < ActiveSupport::TestCase
  setup do
    Offer.delete_all
    SimpleOffer.delete_all
    FinancialTransaction.delete_all
  end

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

  test 'pluck_amount works for multiple single-column attributes' do
    SimpleOffer.create!(price: 10.reais, discount: 5.reais)
    SimpleOffer.create!(price: 50.reais, discount: 25.reais)

    rows = SimpleOffer.order_by_amount(price: :asc).pluck_amount(:price, :discount)

    assert_equal [[10.reais, 5.reais], [50.reais, 25.reais]], rows
  end

  test 'pluck_amount returns empty array for single-column with no records' do
    assert_equal [], SimpleOffer.pluck_amount(:price)
  end

  test 'pluck_amount handles nil amount on single-column attribute' do
    SimpleOffer.create!(price: nil)

    amounts = SimpleOffer.pluck_amount(:price)

    assert_equal [nil], amounts
  end

  test 'pluck_amount works for integer (subunit) single-column attribute' do
    FinancialTransaction.create!(tax: 10.reais)
    FinancialTransaction.create!(tax: 20.reais)

    amounts = FinancialTransaction.pluck_amount(:tax)

    assert_equal [10.reais, 20.reais], amounts
  end

  test 'pluck_amount raises on no attributes' do
    assert_raises(ArgumentError) { Offer.pluck_amount }
  end

  test 'pluck_amount returns arrays for multiple attributes' do
    transaction = FinancialTransaction.create!(
      amount: 100.dollars,
      discount: 20.euros,
      tax: 50,
      price: 15.50.dollars,
      total: 99.99.euros
    )

    rows = FinancialTransaction.where(id: transaction.id).pluck_amount(:amount, :discount, :tax)

    assert_equal [[100.dollars, 20.euros, 50.to_money]], rows
  end

  test 'pluck_amount returns an empty array when there are no records' do
    assert_equal [], Offer.pluck_amount(:price)
  end

  test 'pluck_amount raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.pluck_amount(:product) }
  end

  test 'pluck_amount handles nil amount values' do
    Offer.create!(price: nil)

    amounts = Offer.pluck_amount(:price)

    assert_equal [nil], amounts
  end
end
