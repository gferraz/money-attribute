# frozen_string_literal: true

require 'test_helper'

class AttributeSpecRegistryTest < ActiveSupport::TestCase
  test 'money_amount registers a single-column spec at definition time' do
    spec = FinancialTransaction.money_attribute_spec(:tax)

    assert_predicate spec, :single?
    assert_equal 'tax', spec.name
    assert_equal ['tax'], spec.columns
  end

  test 'money_attribute registers a composite spec at definition time' do
    spec = FinancialTransaction.money_attribute_spec(:total)

    assert_predicate spec, :composite?
    assert_equal 'total', spec.name
    assert_equal %w[total_amount currency_code], spec.columns
  end

  test 'subclasses do not inherit registered money attribute specs automatically' do
    subclass = Class.new(FinancialTransaction)

    assert_nil subclass.money_attribute_spec(:tax)
    assert_nil subclass.money_attribute_spec(:total)
  end

  test 'build_money falls back to default currency for nil currency' do
    spec = FinancialTransaction.money_attribute_spec(:total)
    money = spec.build_money(10, nil)

    assert_equal MoneyAttribute.default_currency.code, money.currency_code
  end

  test 'build_money falls back to XXX for invalid currency' do
    spec = FinancialTransaction.money_attribute_spec(:total)
    money = spec.build_money(10, 'INVALID')

    assert_equal 'XXX', money.currency_code
  end

  test 'build_money returns nil for nil amount' do
    spec = FinancialTransaction.money_attribute_spec(:total)

    assert_nil spec.build_money(nil, 'USD')
  end

  test 'build_money returns Money object unchanged' do
    spec = FinancialTransaction.money_attribute_spec(:total)
    original = 10.dollars

    assert_same original, spec.build_money(original, 'USD')
  end
end
