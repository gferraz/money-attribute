# frozen_string_literal: true

require 'test_helper'

class VariantInputTypeTest < ActiveSupport::TestCase
  setup do
    Offer.delete_all
    SimpleOffer.delete_all
    FinancialTransaction.delete_all
  end

  # --- Composite + Decimal column ---

  test 'composite decimal accepts Float input' do
    offer = Offer.new(price: 45.99)

    assert_equal 45.99.reais, offer.price
    assert_equal BigDecimal('45.99'), offer.price_amount
  end

  test 'composite decimal accepts BigDecimal input' do
    offer = Offer.new(price: BigDecimal('99.50'))

    assert_equal BigDecimal('99.50').to_f.reais, offer.price
    assert_in_delta BigDecimal('99.50'), offer.price_amount
  end

  test 'composite decimal accepts String input' do
    offer = Offer.new(price: '75.25')

    assert_equal 75.25.reais, offer.price
  end

  test 'composite decimal accepts Integer input' do
    offer = Offer.new(price: 42)

    assert_equal 42.reais, offer.price
    assert_equal 42, offer.price_amount
  end

  test 'composite decimal round-trips Float through save and reload' do
    offer = Offer.create!(price: 33.33)
    reloaded = Offer.find(offer.id)

    assert_equal 33.33.reais, reloaded.price
  end

  test 'composite decimal round-trips BigDecimal through save and reload' do
    offer = Offer.create!(price: BigDecimal('44.44'))
    reloaded = Offer.find(offer.id)

    assert_equal BigDecimal('44.44').to_f.reais, reloaded.price
  end

  # --- Composite + Integer column ---

  test 'composite integer accepts Money input' do
    ft = FinancialTransaction.new(amount: 10.dollars)

    assert_equal 10.dollars, ft.amount
    assert_equal 1000, ft[:amount]
  end

  test 'composite integer accepts Integer input' do
    ft = FinancialTransaction.new(amount: 42)

    assert_equal 42.reais, ft.amount
  end

  test 'composite integer accepts Float input' do
    ft = FinancialTransaction.new(amount: 42.50)

    assert_equal 42.50.reais, ft.amount
  end

  test 'composite integer accepts BigDecimal input' do
    ft = FinancialTransaction.new(amount: BigDecimal('25.75'))

    assert_equal BigDecimal('25.75').to_f.reais, ft.amount
  end

  test 'composite integer accepts String input' do
    ft = FinancialTransaction.new(amount: '100.50')

    assert_equal 100.50.reais, ft.amount
  end

  test 'composite integer accepts nil input' do
    ft = FinancialTransaction.new(amount: nil)

    assert_nil ft.amount
  end

  test 'composite integer round-trips Float through save and reload' do
    ft = FinancialTransaction.create!(amount: 33.33, currency: 'USD')
    reloaded = FinancialTransaction.find(ft.id)

    assert_equal 33.33.dollars, reloaded.amount
  end

  test 'composite integer round-trips BigDecimal through save and reload' do
    ft = FinancialTransaction.create!(amount: BigDecimal('44.44'), currency: 'USD')
    reloaded = FinancialTransaction.find(ft.id)

    assert_equal BigDecimal('44.44').to_f.dollars, reloaded.amount
  end

  test 'composite integer round-trips String through save and reload' do
    ft = FinancialTransaction.create!(amount: '55.55', currency: 'USD')
    reloaded = FinancialTransaction.find(ft.id)

    assert_equal 55.55.dollars, reloaded.amount
  end

  # --- Single-column + Decimal ---

  test 'single-column decimal accepts Float input' do
    offer = SimpleOffer.new(price: 45.99)

    assert_equal 45.99.reais, offer.price
  end

  test 'single-column decimal accepts BigDecimal input' do
    offer = SimpleOffer.new(price: BigDecimal('99.50'))

    assert_equal BigDecimal('99.50').to_f.reais, offer.price
  end

  test 'single-column decimal accepts Integer input' do
    offer = SimpleOffer.new(price: 42)

    assert_equal 42.reais, offer.price
  end

  test 'single-column decimal round-trips Float through save and reload' do
    offer = SimpleOffer.create!(price: 33.33)
    reloaded = SimpleOffer.find(offer.id)

    assert_equal 33.33.reais, reloaded.price
  end

  test 'single-column decimal round-trips BigDecimal through save and reload' do
    offer = SimpleOffer.create!(price: BigDecimal('44.44'))
    reloaded = SimpleOffer.find(offer.id)

    assert_equal BigDecimal('44.44').to_f.reais, reloaded.price
  end

  # --- Single-column + Integer (bigint) ---

  test 'single-column integer accepts Money input' do
    ft = FinancialTransaction.new(tax: 10.reais)

    assert_equal 10.reais, ft.tax
  end

  test 'single-column integer accepts Integer input' do
    ft = FinancialTransaction.new(tax: 42)

    assert_equal 42.reais, ft.tax
  end

  test 'single-column integer accepts Float input' do
    ft = FinancialTransaction.new(tax: 42.50)

    assert_equal 42.50.reais, ft.tax
  end

  test 'single-column integer accepts BigDecimal input' do
    ft = FinancialTransaction.new(tax: BigDecimal('25.75'))

    assert_equal BigDecimal('25.75').to_f.reais, ft.tax
  end

  test 'single-column integer accepts String input' do
    ft = FinancialTransaction.new(tax: '100.50')

    assert_equal 100.50.reais, ft.tax
  end

  test 'single-column integer accepts nil input' do
    ft = FinancialTransaction.new(tax: nil)

    assert_nil ft.tax
  end

  test 'single-column integer round-trips Float through save and reload' do
    ft = FinancialTransaction.create!(tax: 33.33)
    reloaded = FinancialTransaction.find(ft.id)

    assert_equal 33.33.reais, reloaded.tax
  end

  test 'single-column integer round-trips BigDecimal through save and reload' do
    ft = FinancialTransaction.create!(tax: BigDecimal('44.44'))
    reloaded = FinancialTransaction.find(ft.id)

    assert_equal BigDecimal('44.44').to_f.reais, reloaded.tax
  end

  test 'single-column integer round-trips String through save and reload' do
    ft = FinancialTransaction.create!(tax: '55.55')
    reloaded = FinancialTransaction.find(ft.id)

    assert_equal 55.55.reais, reloaded.tax
  end
end
