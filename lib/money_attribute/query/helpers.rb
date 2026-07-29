# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module QueryHelpers
    # Returns the registered money attribute spec or raises when missing.
    #
    # @param attr [Symbol, String] the money attribute name
    # @return [AttributeSpec]
    # @raise [ArgumentError] if the attribute is not registered
    def money_attribute_spec!(attr)
      spec = klass.money_attribute_spec(attr)
      raise ArgumentError, "#{attr} is not a money attribute on #{klass.name}" unless spec

      spec
    end

    # Extracts money values for all specs from a single result row.
    #
    # @param row [Array] the flat row from +pluck+ or +pick+
    # @param specs [Array<AttributeSpec>] the money attribute specs
    # @return [Array] the extracted money values
    def extract_money_row(row, specs)
      cursor = 0

      specs.map do |spec|
        value, cursor = extract_attribute_value(row, spec, cursor)
        value
      end
    end

    private

    # Extracts a single value from a flat row at the given cursor position.
    #
    # @param row [Array] the flat row from +pluck+ or +pick+
    # @param spec [AttributeSpec] the money attribute spec
    # @param cursor [Integer] current position in the row array
    # @return [Array(Object, Integer)] the extracted value and updated cursor
    # @api private
    def extract_attribute_value(row, spec, cursor)
      if spec.single?
        [row[cursor], cursor + 1]
      else
        [spec.build_money(row[cursor], row[cursor + 1]), cursor + 2]
      end
    end
  end
end
