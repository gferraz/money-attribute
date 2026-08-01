# frozen_string_literal: true

module MoneyAttribute
  # Internal pluck resolution for the +pluck_amount+ query helper.
  #
  # @api private
  module PluckAmount
    # Plucks money-aware amounts for one or more attributes.
    #
    # @param attrs [Array<Symbol>] one or more registered money attribute names
    # @return [Array<Mint::Money>] for a single attribute
    # @return [Array<Array>] for multiple attributes, one row array per attribute
    # @raise [ArgumentError] if any attribute is not a registered money attribute
    # @api private
    def pluck_amount(*attrs)
      raise ArgumentError, 'No attribute specified' if attrs.empty?

      specs = attrs.map { |attr| money_attribute_spec!(attr) }
      return pluck_single_amount(specs.first) if specs.length == 1

      raw = pluck(*specs.flat_map(&:columns))
      raw.map { |row| extract_money_row(row, specs) }
    end

    private

    # Plucks a single money-aware attribute and returns money values.
    #
    # @param spec [AttributeSpec] the money attribute spec
    # @return [Array] raw values for single-column attributes, composed
    #   +Mint::Money+ values for composite attributes
    # @api private
    def pluck_single_amount(spec)
      return pluck(spec.amount_column) if spec.single?

      pluck(spec.amount_column, spec.currency_column).map { |amount, currency| spec.build_money(amount, currency) }
    end
  end
end
