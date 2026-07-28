# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module PluckAmount
    # Plucks money-aware amounts for one or more attributes.
    #
    # @param attrs [Array<Symbol>] one or more registered money attribute names
    # @return [Array<Mint::Money>] for a single attribute
    # @return [Array<Array>] for multiple attributes, one row array per attribute
    # @raise [ArgumentError] if any attribute is not a registered money attribute
    def pluck_amount(*attrs)
      raise ArgumentError, 'No attribute specified' if attrs.empty?

      specs = attrs.map { |attr| money_attribute_spec!(attr) }
      return pluck_single_amount(specs.first) if specs.length == 1

      raw = pluck(*specs.flat_map(&:columns))
      raw.map { |row| extract_money_row(row, specs) }
    end

    private

    # Plucks a single money-aware attribute and returns money values.
    def pluck_single_amount(spec)
      return pluck(spec.amount_col) if spec.single?

      pluck(spec.amount_col, spec.currency_col).map do |amount, currency|
        spec.build_money(amount, currency)
      end
    end

    # Rebuilds a result row for multi-attribute plucks.
    def extract_money_row(row, specs)
      cursor = 0

      specs.map do |spec|
        value, cursor = extract_pick_value(row, spec, cursor)
        value
      end
    end
  end
end
