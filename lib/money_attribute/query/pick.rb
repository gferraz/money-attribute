# frozen_string_literal: true

module MoneyAttribute
  # Picks a single amount value from a money-aware attribute.
  module PickAmount
    # Picks money-aware amounts for one or more attributes.
    def pick_amount(*attrs)
      raise ArgumentError, 'No attribute specified' if attrs.empty?

      specs = attrs.map { |attr| money_attribute_spec!(attr) }
      return pick_single_amount(specs.first) if specs.length == 1

      raw = pick(*specs.flat_map(&:columns))
      return unless raw

      cursor = 0
      specs.map do |spec|
        value, cursor = extract_pick_value(raw, spec, cursor)
        value
      end
    end

    private

    # Picks a single money-aware attribute and returns a single value.
    def pick_single_amount(spec)
      raw = pick(*spec.columns)
      return unless raw
      return raw if spec.single?

      spec.build_money(raw[0], raw[1])
    end

    # Rebuilds one value from a multi-attribute `pick` result.
    def extract_pick_value(raw, spec, cursor)
      return [raw[cursor], cursor + 1] if spec.single?

      amount = raw[cursor]
      currency = raw[cursor + 1]
      [spec.build_money(amount, currency), cursor + 2]
    end
  end
end
