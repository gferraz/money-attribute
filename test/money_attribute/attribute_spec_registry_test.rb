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

  test 'introspects registered money attributes' do
    assert FinancialTransaction.money_attribute?(:amount)
    assert_equal :composite, FinancialTransaction.money_attribute_kind(:amount)
    assert_equal :single, FinancialTransaction.money_attribute_kind(:tax)
  end

  test 'returns false and nil for an unregistered money attribute' do
    assert_not FinancialTransaction.money_attribute?(:unknown)
    assert_nil FinancialTransaction.money_attribute_kind(:unknown)
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

  test 'invalidates derived caches when a new attribute is registered' do
    model = Class.new(FinancialTransaction)
    model.money_attribute_names_set
    model.money_attribute_name_pattern

    model.register_money_attribute_spec(:late_fee, kind: :single, amount_column: :late_fee, amount_type: :decimal)

    assert_includes model.money_attribute_names_set, 'late_fee'
    assert_match model.money_attribute_name_pattern, 'late_fee < ?'
  end

  test 'invalidates compiled query plans when an attribute is re-registered' do
    model = Class.new(FinancialTransaction)
    sql = 'amount > ?'
    cache = model.money_attribute_query_plan_cache
    cache[sql] = :stale

    model.register_money_attribute_spec(
      :amount,
      kind: :composite,
      amount_column: :amount,
      currency_column: :currency,
      amount_type: :integer
    )

    assert_empty model.money_attribute_query_plan_cache
  end
end
