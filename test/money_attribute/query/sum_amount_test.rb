# frozen_string_literal: true

require 'test_helper'

class SumAmountTest < ActiveSupport::TestCase
  test 'sum_amount returns Hash when multiple currencies exist' do
    Offer.create!(price: 10.euros)
    Offer.create!(price: 20.euros)
    Offer.create!(price: 30.dollars)
    Offer.create!(price: 40.dollars)

    sum = Offer.sum_amount(:price)

    assert_instance_of Hash, sum
    assert_equal %w[EUR USD], sum.keys.sort
    assert_equal 30.euros, sum['EUR']
    assert_equal 70.dollars, sum['USD']
  end

  test 'sum_amount returns single Money when scoped to one currency' do
    Offer.create!(price: 10.euros)
    Offer.create!(price: 20.euros)
    Offer.create!(price: 30.dollars)

    result = Offer.where_currency(price: 'EUR').sum_amount(:price)

    assert_instance_of Mint::Money, result
    assert_equal BigDecimal('30'), result.to_d
    assert_equal 'EUR', result.currency_code
  end

  test 'sum_amount returns single Money when all rows share one currency' do
    Offer.create!(price: 10.euros)
    Offer.create!(price: 20.euros)

    result = Offer.sum_amount(:price)

    assert_instance_of Mint::Money, result
    assert_equal BigDecimal('30'), result.to_d
    assert_equal 'EUR', result.currency_code
  end

  test 'sum_amount works for single-column attribute' do
    SimpleOffer.create!(price: 10.to_money('BRL'))
    SimpleOffer.create!(price: 20.to_money('BRL'))
    SimpleOffer.create!(price: 30.to_money('BRL'))

    result = SimpleOffer.sum_amount(:price)

    assert_instance_of Mint::Money, result
    assert_equal BigDecimal('60'), result.to_d
    assert_equal 'BRL', result.currency_code
  end

  test 'sum_amount handles integer (subunits) column' do
    FinancialTransaction.delete_all
    FinancialTransaction.create!(amount: Mint::Money.from_subunits(1000, 'USD'), currency: 'USD')
    FinancialTransaction.create!(amount: Mint::Money.from_subunits(2000, 'USD'), currency: 'USD')

    result = FinancialTransaction.sum_amount(:amount)

    assert_instance_of Mint::Money, result
    assert_equal 3000, result.subunits
    assert_equal 'USD', result.currency_code
  end

  test 'sum_amount with multiple attributes returns Hash' do
    FinancialTransaction.delete_all
    FinancialTransaction.create!(price_amount: 10, price_currency: 'EUR',
                                 discount: 5, discount_currency: 'EUR')

    result = FinancialTransaction.sum_amount(:price, :discount)

    assert_instance_of Hash, result
    assert_equal BigDecimal('10'), result[:price].to_d
    assert_equal BigDecimal('5'), result[:discount].to_d
  end

  test 'sum_amount returns zero Money for empty result' do
    result = Offer.sum_amount(:price)

    assert_instance_of Mint::Money, result
    assert_equal 0, result
    assert_equal 'BRL', result.currency_code
  end

  test 'sum_amount raises on non-money attribute' do
    assert_raises(ArgumentError) { Offer.sum_amount(:product) }
  end
end
