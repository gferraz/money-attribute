# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module AmountCondition
    ALLOWED_KEYWORDS = %w[and or not is null].to_set.freeze

    # Builds an amount filter for the registered money attribute.
    #
    # @param attr [Symbol] the money attribute name
    # @param value [Mint::Money, Numeric, Range, Array] the filter value
    # @return [ActiveRecord::Relation]
    # @raise [ArgumentError] if the attribute is not a registered money attribute
    def resolve_amount_condition(attr, value)
      spec = money_attribute_spec!(attr)
      col = arel_table[spec.amount_column]

      where(build_amount_predicate(col, spec, value))
    end

    # Builds an amount filter using a SQL string with +?+ placeholders.
    #
    # Only money attribute names, +and+, +or+, +not+, +is+, and +null+ are
    # allowed as identifiers.  +Mint::Money+ bind values are decomposed to
    # raw storage values automatically.
    #
    # @param sql [String] SQL fragment using attribute names and +?+ placeholders
    # @param values [Array] bind values
    # @return [ActiveRecord::Relation]
    # @raise [ArgumentError] on unknown identifiers or placeholder mismatch
    def resolve_amount_condition_from_sql(sql, *values)
      specs = klass.money_attribute_specs
      attr_names = klass.money_attribute_names_set

      validate_sql_identifiers!(sql, attr_names)
      value_specs = map_placeholders_to_specs(sql, specs)
      decomposed = decompose_values(values, value_specs)
      substituted = substitute_attribute_names(sql, specs)

      where(substituted, *decomposed)
    end

    private

    # Builds an Arel predicate for the given amount value.
    def build_amount_predicate(col, spec, value)
      case value
      when Range
        low = normalize_amount_value(spec, value.begin)
        high = normalize_amount_value(spec, value.end)
        pred = col.gteq(low)
        value.exclude_end? ? pred.and(col.lt(high)) : pred.and(col.lteq(high))
      when Array
        col.in(value.map { |v| normalize_amount_value(spec, v) })
      else
        col.eq(normalize_amount_value(spec, value))
      end
    end

    # Normalizes a scalar value for Arel comparison.
    #
    # Composite attributes: the amount column is a plain column with no custom Type,
    # so we must pre-normalize Money to the raw storage value (subunits or decimal).
    # Single-column attributes: the column has a registered Type that handles
    # serialization, so we pass Money objects through directly to avoid double conversion.
    def normalize_amount_value(spec, value)
      return value unless spec.composite?

      spec.normalize_query_value(value)
    end

    # Validates that every word in the SQL is a registered attribute name or an
    # allowed keyword.
    def validate_sql_identifiers!(sql, attr_names)
      sql.scan(/\b[a-z_]\w*\b/i).each do |word|
        next if attr_names.include?(word.downcase) || ALLOWED_KEYWORDS.include?(word.downcase)

        raise ArgumentError, "'#{word}' is not a money attribute on #{klass.name}"
      end
    end

    # Matches each +?+ placeholder to the nearest preceding money attribute name
    # and returns the corresponding spec.
    def map_placeholders_to_specs(sql, specs)
      ref_pattern = klass.money_attribute_name_pattern

      placeholder_positions(sql).map { |pos| spec_at_position(sql, pos, ref_pattern, specs) }
    end

    # Returns character positions of each +?+ in the SQL.
    def placeholder_positions(sql)
      positions = []
      offset = 0

      while (idx = sql.index('?', offset))
        positions << idx
        offset = idx + 1
      end

      positions
    end

    # Returns the spec for the +?+ at the given position.
    def spec_at_position(sql, pos, ref_pattern, specs)
      preceding = sql[0...pos]
      matched = preceding.scan(ref_pattern).flatten.compact

      raise ArgumentError, "No money attribute found before '?' in: #{sql.inspect}" if matched.empty?

      specs[matched.last.downcase]
    end

    # Decomposes +Mint::Money+ bind values to raw storage values using their
    # positional specs.  Unlike +normalize_query_value+ (which relies on the
    # custom type for single-column attributes), this always decomposes since
    # raw SQL bind parameters don't resolve custom types.
    def decompose_values(values, value_specs)
      if values.size != value_specs.size
        raise ArgumentError, "Expected #{value_specs.size} bind value(s), got #{values.size}"
      end

      values.zip(value_specs).map do |val, spec|
        if val.is_a?(Mint::Money)
          spec.integer_amount? ? val.subunits : val.to_d
        else
          val
        end
      end
    end

    # Replaces attribute names with their backing amount column names in the SQL.
    def substitute_attribute_names(sql, specs)
      to_sub = specs_to_substitute(specs)
      return sql if to_sub.empty?

      lookup = to_sub.to_h { |s| [s.name.downcase, s.amount_column] }
      pattern = /\b(#{to_sub.map { |s| Regexp.escape(s.name) }.join('|')})\b/i
      sql.gsub(pattern) { |match| lookup[match.downcase] }
    end

    def specs_to_substitute(specs)
      specs.values.reject { |s| s.name == s.amount_column }
    end
  end
end
