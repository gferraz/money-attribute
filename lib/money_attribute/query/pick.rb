# frozen_string_literal: true

module MoneyAttribute
  # Internal pick resolution for the +pick_amount+ query helper.
  #
  # @api private
  module PickAmount
    # Picks money-aware amounts for one or more attributes.
    #
    # @param attrs [Array<Symbol>] one or more registered money attribute names
    # @return [Mint::Money, Array, nil] Money for a single attribute, row array for multiple, nil if empty
    # @raise [ArgumentError] if any attribute is not a registered money attribute
    # @api private
    def pick_amount(*attrs)
      raise ArgumentError, 'No attribute specified' if attrs.empty?

      specs = attrs.map { |attr| money_attribute_spec!(attr) }
      return pick_single_amount(specs.first) if specs.length == 1

      raw = pick(*specs.flat_map(&:columns))
      return unless raw

      extract_money_row(raw, specs)
    end

    private

    # Picks a single money-aware attribute and returns a single value.
    #
    # @param spec [AttributeSpec] the money attribute spec
    # @return [Mint::Money, Object, nil] the composed Money, the raw value for
    #   single-column attributes, or nil when the relation is empty
    # @api private
    def pick_single_amount(spec)
      raw = pick(*spec.columns)
      return unless raw

      spec.single? ? raw : spec.build_money(raw[0], raw[1])
    end
  end
end
