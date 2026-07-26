# frozen_string_literal: true

require 'test_helper'

class SumAmountTest < ActiveSupport::TestCase
  test 'sum_amount returns Array when multiple currencies exist' do
    Offer.create!(price: 30.dollars)
    Offer.create!(price: 40.dollars)
    Offer.create!(price: 10.euros)
    Offer.create!(price: 20.euros)

    assert_equal [30.euros, 70.dollars], Offer.sum_amount(:price)
  end

  test 'sum_amount returns Array when scoped to one currency' do
    Offer.create!(price: 10.euros)
    Offer.create!(price: 20.euros)
    Offer.create!(price: 30.dollars)

    assert_equal [30.euros], Offer.where_currency(price: 'EUR').sum_amount(:price)
  end

  test 'sum_amount returns Array when all rows share one currency' do
    Offer.create!(price: 10.euros)
    Offer.create!(price: 20.euros)

    assert_equal [30.euros], Offer.sum_amount(:price)
  end

  test 'sum_amount works for single-column attribute' do
    SimpleOffer.create!(price: 10.reais)
    SimpleOffer.create!(price: 20.reais)
    SimpleOffer.create!(price: 30.reais)

    assert_equal [60.reais], SimpleOffer.sum_amount(:price)
  end

  test 'sum_amount handles integer (subunits) column' do
    FinancialTransaction.delete_all
    FinancialTransaction.create!(amount: Mint::Money.from_subunits(1000, 'USD'), currency: 'USD')
    FinancialTransaction.create!(amount: Mint::Money.from_subunits(2000, 'USD'), currency: 'USD')

    assert_equal [30.00.dollars], FinancialTransaction.sum_amount(:amount)
  end

  test 'sum_amount rejects multiple attributes' do
    assert_raises(ArgumentError) do
      FinancialTransaction.sum_amount(:price, :discount)
    end
  end

  test 'sum_amount returns Array with zero Money for empty result' do
    assert_equal [0], Offer.sum_amount(:price)
  end

  test 'sum_amount raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.sum_amount(:product) }
  end
end
