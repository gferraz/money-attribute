# frozen_string_literal: true

module MoneyAttribute
  # Picks a single amount value from a money-aware attribute.
  module PickAmount
    def pick_amount(*attrs)
      raise ArgumentError, 'No attribute specified' if attrs.empty?

      specs = attrs.map { |attr| money_attribute_spec!(attr) }
      return pick_single_amount(specs.first) if specs.length == 1

      raw = pick(*specs.flat_map(&:columns))
      return raw if raw.nil?

      cursor = 0
      specs.map do |spec|
        value, cursor = extract_pick_value(raw, spec, cursor)
        value
      end
    end

    private

    def pick_single_amount(spec)
      raw = pick(*spec.columns)
      return raw if raw.nil?

      return raw if spec.single?

      build_money_value(raw[0], raw[1], spec.amount_col)
    end

    def extract_pick_value(raw, spec, cursor)
      return [raw[cursor], cursor + 1] if spec.single?

      amount = raw[cursor]
      currency = raw[cursor + 1]
      [build_money_value(amount, currency, spec.amount_col), cursor + 2]
    end
  end
end
