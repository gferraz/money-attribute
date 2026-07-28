# frozen_string_literal: true

require 'test_helper'

class SingleIntegerQueryTest < ActiveSupport::TestCase
  setup do
    FinancialTransaction.delete_all
  end

  # --- where_amount ---

  test 'where_amount with scalar on single-column integer attribute' do
    FinancialTransaction.create!(tax: 10.reais)
    FinancialTransaction.create!(tax: 20.reais)
    FinancialTransaction.create!(tax: 30.reais)

    amounts = FinancialTransaction.where_amount(tax: 20.reais).map(&:tax)

    assert_equal [20.reais], amounts
  end

  test 'where_amount with range on single-column integer attribute' do
    FinancialTransaction.create!(tax: 10.reais)
    FinancialTransaction.create!(tax: 20.reais)
    FinancialTransaction.create!(tax: 30.reais)

    amounts = FinancialTransaction.where_amount(tax: (10.reais)..(20.reais)).map(&:tax)

    assert_equal [10.reais, 20.reais], amounts
  end

  test 'where_amount with array on single-column integer attribute' do
    FinancialTransaction.create!(tax: 10.reais)
    FinancialTransaction.create!(tax: 20.reais)
    FinancialTransaction.create!(tax: 30.reais)

    amounts = FinancialTransaction.where_amount(tax: [10.reais, 30.reais]).map(&:tax)

    assert_equal [10.reais, 30.reais], amounts
  end

  # --- order_by_amount ---

  test 'order_by_amount ascending on single-column integer attribute' do
    FinancialTransaction.create!(tax: 100.reais)
    FinancialTransaction.create!(tax: 10.reais)
    FinancialTransaction.create!(tax: 50.reais)

    amounts = FinancialTransaction.order_by_amount(tax: :asc).pluck_amount(:tax)

    assert_equal [10.reais, 50.reais, 100.reais], amounts
  end

  test 'order_by_amount descending on single-column integer attribute' do
    FinancialTransaction.create!(tax: 10.reais)
    FinancialTransaction.create!(tax: 100.reais)
    FinancialTransaction.create!(tax: 50.reais)

    amounts = FinancialTransaction.order_by_amount(tax: :desc).pluck_amount(:tax)

    assert_equal [100.reais, 50.reais, 10.reais], amounts
  end

  # --- pick_amount ---

  test 'pick_amount returns Money for single-column integer attribute' do
    FinancialTransaction.create!(tax: 10.reais)
    FinancialTransaction.create!(tax: 20.reais)

    amount = FinancialTransaction.order_by_amount(tax: :asc).pick_amount(:tax)

    assert_equal 10.reais, amount
  end

  test 'pick_amount returns nil for single-column integer with no records' do
    assert_nil FinancialTransaction.pick_amount(:tax)
  end

  # --- sum_amount ---

  test 'sum_amount works for single-column integer attribute' do
    FinancialTransaction.create!(tax: 10.reais)
    FinancialTransaction.create!(tax: 20.reais)
    FinancialTransaction.create!(tax: 30.reais)

    totals = FinancialTransaction.sum_amount(:tax)

    assert_equal [60.reais], totals
  end

  test 'sum_amount returns zero Money for empty single-column integer' do
    totals = FinancialTransaction.sum_amount(:tax)

    assert_equal [Mint::Money.from(0, MoneyAttribute.default_currency)], totals
  end

  # --- where_currency raises ---

  test 'where_currency raises on single-column integer attribute' do
    error = assert_raises(ArgumentError) { FinancialTransaction.where_currency(tax: 'BRL') }

    assert_match(/money_amount/, error.message)
  end
end
