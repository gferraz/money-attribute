# frozen_string_literal: true

require_relative 'query/helpers'
require_relative 'query/money_condition'
require_relative 'query/currency_condition'
require_relative 'query/amount_condition'
require_relative 'query/amount_order'
require_relative 'query/sum'

module MoneyAttribute
  # Money-aware query helpers for ActiveRecord.
  #
  #   Offer.where_money(price: 10.euros..100.euros)
  #   Offer.where_currency(price: 'EUR')
  #   Offer.where_amount(price: 10..100)
  #   Offer.order_by_amount(price: :desc)
  #   Offer.sum_amount(:price)
  #
  module Query
    extend ActiveSupport::Concern

    class_methods do
      def where_money(conditions)
        scope = all
        conditions.each { |attr, value| scope = scope.resolve_money_condition(attr, value) }
        scope
      end

      def where_currency(conditions)
        scope = all
        conditions.each { |attr, value| scope = scope.resolve_currency_condition(attr, value) }
        scope
      end

      def where_amount(conditions)
        scope = all
        conditions.each { |attr, value| scope = scope.resolve_amount_condition(attr, value) }
        scope
      end

      def order_by_amount(conditions)
        scope = all
        conditions.each { |attr, dir| scope = scope.resolve_amount_order(attr, dir || :asc) }
        scope
      end

      def sum_amount(*attrs)
        all.sum_amount(*attrs)
      end
    end
  end

  # Internal methods mixed into ActiveRecord::Relation for query building.
  module QueryMethods
    include QueryHelpers
    include MoneyCondition
    include CurrencyCondition
    include AmountCondition
    include AmountOrder
    include SumAmount
  end
end

ActiveSupport.on_load(:active_record) do
  include MoneyAttribute::Query
  ActiveRecord::Relation.include(MoneyAttribute::QueryMethods)
end
