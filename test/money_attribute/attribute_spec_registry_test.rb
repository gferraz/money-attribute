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
end
