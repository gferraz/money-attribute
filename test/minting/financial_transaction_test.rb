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

    test 'discount money attribute does not conflict with amount' do
      transaction = FinancialTransaction.new(amount: 45.34.dollars, discount: 10.euros)

      assert_equal 45.34.dollars, transaction.amount
      assert_equal 10.euros, transaction.discount
      assert_equal 'USD', transaction.currency
      assert_equal 'EUR', transaction.discount_currency
      refute_equal transaction.amount, transaction.discount
    end

    test 'discount and amount persist independently' do
      transaction = FinancialTransaction.create!(amount: 100.dollars, discount: 20.euros,
                                                  description: 'independent')
      transaction.save!
      reloaded = FinancialTransaction.find(transaction.id)

      assert_equal 100.dollars, reloaded.amount
      assert_equal 20.euros, reloaded.discount
      assert_equal 'independent', reloaded.description
    end

    test 'discount can be updated without affecting amount' do
      transaction = FinancialTransaction.create!(amount: 50.dollars, discount: 10.euros)
      transaction.update!(discount: 15.euros)

      assert_equal 50.dollars, transaction.amount
      assert_equal 15.euros, transaction.discount
    end

    test 'discount fractional column is independent from amount fractional' do
      transaction = FinancialTransaction.new(amount: 30.dollars, discount: 5.euros)

      assert_equal 3000, transaction[:amount]
      assert_equal 500, transaction[:discount]
      assert_equal 'USD', transaction[:currency]
      assert_equal 'EUR', transaction[:discount_currency]
    end

    test 'tax is a single-column fixed-currency attribute' do
      transaction = FinancialTransaction.new(tax: 100)

      assert_equal 100.mint(Mint.default_currency), transaction.tax
    end

    test 'tax does not conflict with amount or discount' do
      transaction = FinancialTransaction.new(
        amount: 45.34.dollars,
        discount: 10.euros,
        tax: 200
      )

      assert_equal 45.34.dollars, transaction.amount
      assert_equal 10.euros, transaction.discount
      assert_equal 200.mint(Mint.default_currency), transaction.tax
      assert_equal 'USD', transaction.currency
      assert_equal 'EUR', transaction.discount_currency
    end

    test 'tax, amount, and discount persist independently' do
      transaction = FinancialTransaction.create!(
        amount: 100.dollars,
        discount: 20.euros,
        tax: 50,
        description: 'all three'
      )
      reloaded = FinancialTransaction.find(transaction.id)

      assert_equal 100.dollars, reloaded.amount
      assert_equal 20.euros, reloaded.discount
      assert_equal 50.mint(Mint.default_currency), reloaded.tax
    end

    test 'tax uses bigint column storing fractional (cents)' do
      transaction = FinancialTransaction.create!(tax: 12.34.mint('BRL'))

      assert_equal 1234, FinancialTransaction.connection.select_all(
        'SELECT tax FROM financial_transactions WHERE id = ?', 'SQL', [transaction.id]
      ).first['tax']
    end

    test 'column inference is independent of money_attribute declaration order' do
      reversed = Class.new(ApplicationRecord) do
        self.table_name = 'financial_transactions'

        money_attribute :tax
        money_attribute :discount
        money_attribute :amount
      end

      record = reversed.new(amount: 45.34.dollars, discount: 10.euros, tax: 200)

      assert_equal 45.34.dollars, record.amount
      assert_equal 'USD', record.currency
      assert_equal 10.euros, record.discount
      assert_equal 'EUR', record.discount_currency
      assert_equal 200.mint(Mint.default_currency), record.tax
    end

    test 'price is a convention composite attribute with decimal columns' do
      transaction = FinancialTransaction.new(price: 29.99.euros)

      assert_equal 29.99.euros, transaction.price
      assert_equal 29.99, transaction.price_amount
      assert_equal 'EUR', transaction.price_currency
    end

    test 'price saves and reloads correctly' do
      transaction = FinancialTransaction.create!(price: 9.99.dollars)
      reloaded = FinancialTransaction.find(transaction.id)

      assert_equal 9.99.dollars, reloaded.price
    end

    test 'total uses explicit mapping with custom column names' do
      transaction = FinancialTransaction.new(total: 150.50.dollars)

      assert_equal 150.50.dollars, transaction.total
      assert_equal 150.50, transaction.total_amount
      assert_equal 'USD', transaction.currency_code
    end

    test 'total saves and reloads correctly' do
      transaction = FinancialTransaction.create!(total: 250.euros)
      reloaded = FinancialTransaction.find(transaction.id)

      assert_equal 250.euros, reloaded.total
    end

    test 'all five money attributes coexist without conflicts' do
      transaction = FinancialTransaction.new(
        amount: 100.dollars,
        discount: 20.euros,
        price: 15.50.dollars,
        tax: 500,
        total: 99.99.euros
      )

      assert_equal 100.dollars, transaction.amount
      assert_equal 20.euros, transaction.discount
      assert_equal 15.50.dollars, transaction.price
      assert_equal 500.mint(Mint.default_currency), transaction.tax
      assert_equal 99.99.euros, transaction.total
      assert_equal 'USD', transaction.currency
      assert_equal 'EUR', transaction.discount_currency
      assert_equal 'USD', transaction.price_currency
      assert_equal 'EUR', transaction.currency_code

      transaction.save!
      reloaded = FinancialTransaction.find(transaction.id)

      assert_equal 100.dollars, reloaded.amount
      assert_equal 20.euros, reloaded.discount
      assert_equal 15.50.dollars, reloaded.price
      assert_equal 500.mint(Mint.default_currency), reloaded.tax
      assert_equal 99.99.euros, reloaded.total
    end
  end
end
