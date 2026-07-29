# frozen_string_literal: true

require 'test_helper'

class WhereAmountStringTest < ActiveSupport::TestCase
  setup do
    FinancialTransaction.delete_all
    SimpleOffer.delete_all
  end

  # --- relational operators ---

  test '< operator' do
    FinancialTransaction.create!(amount: 10.dollars, discount: 5.dollars, currency: 'USD',
                                 discount_currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, discount: 5.dollars, currency: 'USD',
                                 discount_currency: 'USD')

    result = FinancialTransaction.where_amount('amount < ?', 10.dollars)

    assert_equal [5.dollars], result.map(&:amount)
  end

  test '<= operator' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount('amount <= ?', 10.dollars)

    assert_equal [5.dollars, 10.dollars], result.sort_by(&:amount).map(&:amount)
  end

  test '> operator' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount('amount > ?', 10.dollars)

    assert_equal [], result.map(&:amount)
  end

  test '>= operator' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount('amount >= ?', 10.dollars)

    assert_equal [10.dollars], result.map(&:amount)
  end

  test '= operator' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount('amount = ?', 10.dollars)

    assert_equal [10.dollars], result.map(&:amount)
  end

  test '!= operator' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount('amount != ?', 10.dollars)

    assert_equal [5.dollars], result.map(&:amount)
  end

  test '<> operator' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount('amount <> ?', 10.dollars)

    assert_equal [5.dollars], result.map(&:amount)
  end

  # --- boolean operators ---

  test 'AND between two attributes' do
    FinancialTransaction.create!(amount: 10.dollars, discount: 5.dollars, currency: 'USD',
                                 discount_currency: 'USD')
    FinancialTransaction.create!(amount: 20.dollars, discount: 2.dollars, currency: 'USD',
                                 discount_currency: 'USD')

    result = FinancialTransaction.where_amount('amount > ? AND discount < ?', 10.dollars, 5.dollars)

    assert_equal [20.dollars], result.map(&:amount)
  end

  test 'AND between two attributes (lowercase)' do
    FinancialTransaction.create!(amount: 10.dollars, discount: 5.dollars, currency: 'USD',
                                 discount_currency: 'USD')
    FinancialTransaction.create!(amount: 20.dollars, discount: 2.dollars, currency: 'USD',
                                 discount_currency: 'USD')

    result = FinancialTransaction.where_amount('amount > ? and discount < ?', 10.dollars, 5.dollars)

    assert_equal [20.dollars], result.map(&:amount)
  end

  test 'OR' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount('amount = ? OR amount = ?', 10.dollars, 20.dollars)

    assert_equal [10.dollars], result.map(&:amount)
  end

  test 'NOT' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 20.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount('NOT amount = ?', 10.dollars)

    assert_equal [20.dollars], result.map(&:amount)
  end

  test 'NOT with AND' do
    FinancialTransaction.create!(amount: 10.dollars, discount: 5.dollars, currency: 'USD',
                                 discount_currency: 'USD')
    FinancialTransaction.create!(amount: 20.dollars, discount: 8.dollars, currency: 'USD',
                                 discount_currency: 'USD')

    result = FinancialTransaction.where_amount('NOT amount = ? AND discount < ?', 10.dollars, 10.dollars)

    assert_equal [20.dollars], result.map(&:amount)
  end

  # --- IS NULL / IS NOT NULL ---

  test 'IS NULL' do
    FinancialTransaction.create!(amount: nil, currency: 'USD')
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount('amount IS NULL')

    assert_equal [nil], result.map(&:amount)
  end

  test 'IS NOT NULL' do
    FinancialTransaction.create!(amount: nil, currency: 'USD')
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount('amount IS NOT NULL')

    assert_equal [10.dollars], result.map(&:amount)
  end

  # --- grouping ---

  test 'parenthesized grouping' do
    FinancialTransaction.create!(amount: 10.dollars, discount: 3.dollars, currency: 'USD',
                                 discount_currency: 'USD')
    FinancialTransaction.create!(amount: 15.dollars, discount: 10.dollars, currency: 'USD',
                                 discount_currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, discount: 3.dollars, currency: 'USD',
                                 discount_currency: 'USD')

    result = FinancialTransaction.where_amount(
      '(amount > ? OR discount > ?) AND amount < ?', 10.dollars, 7.dollars, 20.dollars
    )

    assert_equal [15.dollars], result.map(&:amount)
  end

  # --- attribute name vs column name ---

  test 'attribute name substituted when it differs from column name' do
    FinancialTransaction.create!(price: 10.dollars)
    FinancialTransaction.create!(price: 5.dollars)

    result = FinancialTransaction.where_amount('price < ?', 10.dollars)

    assert_equal [5.dollars], result.map(&:price)
  end

  # --- single-column attributes ---

  test 'single-column attribute' do
    SimpleOffer.create!(price: 10.reais)
    SimpleOffer.create!(price: 5.reais)

    result = SimpleOffer.where_amount('price < ?', 10.reais)

    assert_equal [5.reais], result.map(&:price)
  end

  test 'single-column attribute with AND' do
    SimpleOffer.create!(price: 10.reais, discount: 5.reais)
    SimpleOffer.create!(price: 20.reais, discount: 8.reais)

    result = SimpleOffer.where_amount('price > ? AND discount < ?', 10.reais, 10.reais)

    assert_equal [20.reais], result.map(&:price)
  end

  # --- same attribute, multiple placeholders ---

  test 'same attribute with multiple placeholders' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 15.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount('amount >= ? AND amount <= ?', 5.dollars, 10.dollars)

    assert_equal [5.dollars, 10.dollars], result.sort_by(&:amount).map(&:amount)
  end

  # --- integer (subunit) composite attribute ---

  test 'integer composite attribute decomposes to subunits' do
    FinancialTransaction.create!(amount: 100.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 50.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount('amount > ?', 50.dollars)

    assert_equal [100.dollars], result.map(&:amount)
  end

  # --- error cases ---

  test 'raises on unknown identifier' do
    assert_raises(ArgumentError) { FinancialTransaction.where_amount('foo < ?', 10.dollars) }
  end

  test 'raises on unsupported keyword' do
    assert_raises(ArgumentError) { FinancialTransaction.where_amount('amount BETWEEN ? AND ?', 10.dollars, 20.dollars) }
  end

  test 'raises on raw column name' do
    assert_raises(ArgumentError) { FinancialTransaction.where_amount('price_amount < ?', 10.dollars) }
  end

  test 'raises when too many values' do
    assert_raises(ArgumentError) { FinancialTransaction.where_amount('amount < ?', 10.dollars, 20.dollars) }
  end

  test 'raises when too few values' do
    assert_raises(ArgumentError) { FinancialTransaction.where_amount('amount < ? AND discount > ?', 10.dollars) }
  end

  test 'raises on no money attribute before placeholder' do
    assert_raises(ArgumentError) do
      FinancialTransaction.where_amount('amount > ? AND foo < ?', 10.dollars, 20.dollars)
    end
  end

  # --- hash form still works ---

  test 'hash form still works' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount(amount: 10.dollars)

    assert_equal [10.dollars], result.map(&:amount)
  end

  test 'hash form with range still works' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 15.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount(amount: (5.dollars)..(10.dollars))

    assert_equal [5.dollars, 10.dollars], result.sort_by(&:amount).map(&:amount)
  end

  test 'hash form with array still works' do
    FinancialTransaction.create!(amount: 10.dollars, currency: 'USD')
    FinancialTransaction.create!(amount: 5.dollars, currency: 'USD')

    result = FinancialTransaction.where_amount(amount: [10.dollars, 20.dollars])

    assert_equal [10.dollars], result.map(&:amount)
  end
end
