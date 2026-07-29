# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module PickAmount
    # Picks money-aware amounts for one or more attributes.
    #
    # @param attrs [Array<Symbol>] one or more registered money attribute names
    # @return [Mint::Money, Array, nil] Money for a single attribute, row array for multiple, nil if empty
    # @raise [ArgumentError] if any attribute is not a registered money attribute
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
    def pick_single_amount(spec)
      raw = pick(*spec.columns)
      return unless raw

      spec.single? ? raw : spec.build_money(raw[0], raw[1])
    end
  end
end
