# frozen_string_literal: true

module MoneyAttribute
  # Internal amount-filter resolution for the +where_amount+ query helper.
  #
  # Supports two input forms: a hash of attribute/value pairs resolved to Arel
  # predicates, and a SQL string with +?+ placeholders where attribute names
  # are substituted for backing columns and +Mint::Money+ binds are decomposed.
  #
  # @api private
  module AmountCondition
    ALLOWED_KEYWORDS = %w[and or not is null].to_set.freeze
    QueryPlan = Struct.new(:sql, :value_specs, keyword_init: true)

    # Builds an amount filter for the registered money attribute.
    #
    # @param attr [Symbol] the money attribute name
    # @param value [Mint::Money, Numeric, Range, Array] the filter value
    # @return [ActiveRecord::Relation]
    # @raise [ArgumentError] if the attribute is not a registered money attribute
    # @api private
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
    # @api private
    def resolve_amount_condition_from_sql(sql, *values)
      plan = klass.money_attribute_query_plan_cache.fetch_or_store(sql) do
        compile_query_plan(sql)
      end
      decomposed = decompose_values(values, plan.value_specs)

      where(plan.sql, *decomposed)
    end

    private

    # Compiles a string query into substituted SQL and bind metadata.
    #
    # @param sql [String] the SQL fragment
    # @return [QueryPlan] the compiled query plan
    # @api private
    def compile_query_plan(sql)
      specs = klass.money_attribute_specs
      value_specs = parse_sql_value_specs(sql, specs)

      QueryPlan.new(
        sql: substitute_attribute_names(sql, specs),
        value_specs: value_specs.freeze
      ).freeze
    end

    # Builds an Arel predicate for the given amount value.
    #
    # @param col [Arel::Attributes::Attribute] the amount column node
    # @param spec [AttributeSpec] the money attribute spec
    # @param value [Mint::Money, Numeric, Range, Array] the filter value
    # @return [Arel::Nodes::Node] the predicate
    # @api private
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
    #
    # @param spec [AttributeSpec] the money attribute spec
    # @param value [Object] the value to normalize
    # @return [Object] the normalized value
    # @api private
    def normalize_amount_value(spec, value)
      return value unless spec.composite?

      spec.normalize_query_value(value)
    end

    # Validates identifiers and associates placeholders with the nearest
    # preceding money attribute in one left-to-right pass.
    #
    # @param sql [String] the SQL fragment
    # @param specs [Hash{String => AttributeSpec}] the money attribute specs
    # @return [Array<AttributeSpec>] one spec per bind value
    # @raise [ArgumentError] on an unknown identifier or unassociated placeholder
    # @api private
    def parse_sql_value_specs(sql, specs)
      current_spec = nil
      value_specs = []

      sql.scan(/[a-z_]\w*|\?/i) do |token|
        if token == '?'
          raise ArgumentError, "No money attribute found before '?' in: #{sql.inspect}" unless current_spec

          value_specs << current_spec
          next
        end

        word = token.downcase
        next if ALLOWED_KEYWORDS.include?(word)

        current_spec = specs[word]
        raise ArgumentError, "'#{token}' is not a money attribute on #{klass.name}" unless current_spec
      end

      value_specs
    end

    # Decomposes +Mint::Money+ bind values to raw storage values using their
    # positional specs.  Unlike +normalize_query_value+ (which relies on the
    # custom type for single-column attributes), this always decomposes since
    # raw SQL bind parameters don't resolve custom types.
    #
    # @param values [Array] the bind values
    # @param value_specs [Array<AttributeSpec>] one spec per bind value
    # @return [Array] decomposed bind values
    # @raise [ArgumentError] if the number of values and specs differs
    # @api private
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
    #
    # Only attributes whose name differs from their amount column are
    # substituted; the rest are already valid column references.
    #
    # @param sql [String] the SQL fragment
    # @param specs [Hash{String => AttributeSpec}] the money attribute specs
    # @return [String] the SQL with attribute names replaced by column names
    # @api private
    def substitute_attribute_names(sql, specs)
      to_sub = specs_to_substitute(specs)
      return sql if to_sub.empty?

      lookup = to_sub.to_h { |s| [s.name.downcase, s.amount_column] }
      pattern = /\b(#{to_sub.map { |s| Regexp.escape(s.name) }.join('|')})\b/i
      sql.gsub(pattern) { |match| lookup[match.downcase] }
    end

    # Returns the specs whose attribute name differs from their amount column.
    #
    # @param specs [Hash{String => AttributeSpec}] the money attribute specs
    # @return [Array<AttributeSpec>] specs needing SQL substitution
    # @api private
    def specs_to_substitute(specs)
      specs.values.reject { |s| s.name == s.amount_column }
    end
  end
end
