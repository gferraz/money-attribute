# frozen_string_literal: true

require 'test_helper'

class CompositeIntegerQueryTest < ActiveSupport::TestCase
  setup do
    FinancialTransaction.delete_all
  end

  # --- where_amount ---

  test 'where_amount with scalar on integer composite column' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 20.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 10.euros, currency: 'EUR')

    amounts = FinancialTransaction.where_amount(amount: 10.dollars).map(&:amount)

    assert_equal [10.dollars, 10.euros], amounts
  end

  test 'where_amount with exclusive range on integer composite column' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 50.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 100.dollars, currency: 'USD')

    amounts = FinancialTransaction.where_amount(amount: (10.dollars)...(100.dollars)).map(&:amount)

    assert_equal [10.dollars, 50.dollars], amounts
  end

  # --- order_by_amount ---

  test 'order_by_amount ascending on integer composite column' do
    FinancialTransaction.create!(amount: 100.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 50.euros, currency: 'EUR')

    amounts = FinancialTransaction.order_by_amount(amount: :asc).pluck_amount(:amount)

    assert_equal [50.euros, 10.dollars, 100.dollars], amounts
  end

  test 'order_by_amount descending on integer composite column' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 100.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 50.euros, currency: 'EUR')

    amounts = FinancialTransaction.order_by_amount(amount: :desc).pluck_amount(:amount)

    assert_equal [50.euros, 100.dollars, 10.dollars], amounts
  end

  # --- pluck_amount ---

  test 'pluck_amount single attribute on integer composite column' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 20.euros, currency: 'EUR')

    amounts = FinancialTransaction.pluck_amount(:amount)

    assert_equal [10.dollars, 20.euros], amounts
  end

  test 'pluck_amount multiple attributes on integer composite column' do
    FinancialTransaction.create!(amount: 10.dollars, discount: 5.euros, currency: 'USD',
                                 discount_currency: 'EUR')

    rows = FinancialTransaction.pluck_amount(:amount, :discount)

    assert_equal [[10.dollars, 5.euros]], rows
  end

  test 'pluck_amount returns empty array for integer composite with no records' do
    assert_equal [], FinancialTransaction.pluck_amount(:amount)
  end

  test 'pluck_amount handles nil amount on integer composite column' do
    FinancialTransaction.create!(amount: nil, currency: 'USD')

    amounts = FinancialTransaction.pluck_amount(:amount)

    assert_equal [nil], amounts
  end

  # --- pick_amount ---

  test 'pick_amount returns Money for integer composite column' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 20.euros, currency: 'EUR')

    amount = FinancialTransaction.order_by_amount(amount: :asc).pick_amount(:amount)

    assert_equal 20.euros, amount
  end

  test 'pick_amount returns nil for integer composite with no records' do
    assert_nil FinancialTransaction.pick_amount(:amount)
  end

  # --- sum_amount ---

  test 'sum_amount returns per-currency sums for integer composite column' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 20.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 30.euros, currency: 'EUR')
    FinancialTransaction.create!(amount: 40.euros, currency: 'EUR')

    totals = FinancialTransaction.sum_amount(:amount)

    assert_equal [70.euros, 30.dollars], totals
  end

  test 'sum_amount returns single currency sum for integer composite column' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 20.dollars, currency: 'USD')

    totals = FinancialTransaction.sum_amount(:amount)

    assert_equal [30.dollars], totals
  end

  test 'sum_amount returns zero Money for empty integer composite' do
    totals = FinancialTransaction.sum_amount(:amount)

    assert_equal [Mint::Money.from(0, MoneyAttribute.default_currency)], totals
  end
end
