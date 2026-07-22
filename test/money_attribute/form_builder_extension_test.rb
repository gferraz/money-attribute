# frozen_string_literal: true

require 'test_helper'

class FormBuilderExtensionTest < ActionDispatch::IntegrationTest
  setup do
    @transaction = FinancialTransaction.create!(
      amount: 12.34.dollars,
      discount: 5.euros,
      price: 99.99.dollars,
      tax: 50.to_money,
      total: 200.euros,
      description: 'test',
      date: Time.zone.now
    )
  end

  test 'new form renders all money fields' do
    get new_financial_transaction_url

    assert_response :success

    assert_select 'input[name="financial_transaction[amount]"]'
    assert_select 'input[name="financial_transaction[discount]"]'
    assert_select 'input[name="financial_transaction[price]"]'
    assert_select 'input[name="financial_transaction[total]"]'
    assert_select 'input[name="financial_transaction[tax]"]'
  end

  test 'money_field renders text input with formatted value on edit' do
    get edit_financial_transaction_url(@transaction)

    assert_response :success

    assert_select 'input[name="financial_transaction[amount]"][type="text"]' do |inputs|
      value = inputs.first.attributes['value']&.value

      assert_predicate value, :present?, 'Expected money_field to have a formatted value'
    end
  end

  test 'money_amount_field renders number input with numeric value on edit' do
    get edit_financial_transaction_url(@transaction)

    assert_response :success

    assert_select 'input[name="financial_transaction[tax]"][type="number"]' do |inputs|
      assert_equal '50.0', inputs.first.attributes['value']&.value
    end
  end

  test 'money fields have correct dom ids' do
    get edit_financial_transaction_url(@transaction)

    assert_response :success

    assert_select 'input#financial_transaction_amount'
    assert_select 'input#financial_transaction_discount'
    assert_select 'input#financial_transaction_price'
    assert_select 'input#financial_transaction_total'
    assert_select 'input#financial_transaction_tax'
  end

  test 'creating a record via form persists money attributes' do
    post financial_transactions_url, params: {
      financial_transaction: {
        description: 'created via form',
        date: Time.zone.now,
        amount: 25.to_money('USD').to_fs,
        tax: 100
      }
    }

    assert_response :redirect
    follow_redirect!

    assert_response :success

    created = FinancialTransaction.last

    assert_equal 'created via form', created.description
    assert_equal 25.dollars, created.amount
  end

  test 'updating record via form changes money attributes' do
    patch financial_transaction_url(@transaction), params: {
      financial_transaction: {
        description: 'updated via form',
        amount: 75.to_money('USD').to_fs
      }
    }

    assert_response :redirect
    follow_redirect!

    assert_response :success

    @transaction.reload

    assert_equal 'updated via form', @transaction.description
    assert_equal 75.dollars, @transaction.amount
  end

  test 'show page renders money attributes without error' do
    get financial_transaction_url(@transaction)

    assert_response :success
  end

  test 'index page renders money attributes without error' do
    get financial_transactions_url

    assert_response :success
  end
end
