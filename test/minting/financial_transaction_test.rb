# frozen_string_literal: true

require 'test_helper'

module Mint
  class FinancialTransactionTest < ActiveSupport::TestCase
    test 'aggregated money attribute with integer amount column' do
      transaction = FinancialTransaction.new(amount: 45.34.dollars)

      assert_equal 45.34.dollars, transaction.amount
      assert_equal 4534, transaction[:amount]
      assert_equal 'USD', transaction.currency
    end

    test 'aggregated money attribute with integer column saves and reloads' do
      transaction = FinancialTransaction.new(amount: 12.50.dollars, description: 'test')
      transaction.save!

      reloaded = FinancialTransaction.find(transaction.id)

      assert_equal 12.50.dollars, reloaded.amount
      assert_equal 'test', reloaded.description
    end

    test 'aggregated money attribute with integer column queries by raw columns' do
      FinancialTransaction.create!(amount: 5.euros, description: 'eur')
      FinancialTransaction.create!(amount: 10.dollars, description: 'usd')

      found = FinancialTransaction.where(amount: 5.euros).first

      assert_equal 5.euros, found.amount
      assert_equal 'eur', found.description
    end

    test 'aggregated money attribute with integer column handles different currencies' do
      transaction = FinancialTransaction.new(amount: 7.euros, description: 'multi')

      assert_equal 7.euros, transaction.amount
      assert_equal 'EUR', transaction.currency

      transaction.save!
      reloaded = FinancialTransaction.find(transaction.id)

      assert_equal 7.euros, reloaded.amount
    end

    test 'money attribute uses :fractional extractor for integer columns' do
      assert_equal :fractional, FinancialTransaction.amount_extractor_for(:amount)
    end
  end
end
