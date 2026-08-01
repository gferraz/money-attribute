# frozen_string_literal: true

module MoneyAttribute
  # Internal ordering resolution for the +order_by_amount+ query helper.
  #
  # @api private
  module AmountOrder
    # Builds an amount ordering for the registered money attribute.
    #
    # Composite attributes order by currency ASC first, then amount in the
    # requested direction. Single-column attributes order by amount only.
    #
    # @param attr [Symbol] the money attribute name
    # @param direction [Symbol] +:asc+ or +:desc+
    # @return [ActiveRecord::Relation]
    # @raise [ArgumentError] if the attribute is not a registered money attribute
    # @api private
    def resolve_amount_order(attr, direction)
      spec = money_attribute_spec!(attr)

      if spec.composite?
        order(spec.currency_column => :asc, spec.amount_column => direction)
      else
        order(spec.amount_column => direction)
      end
    end
  end
end
