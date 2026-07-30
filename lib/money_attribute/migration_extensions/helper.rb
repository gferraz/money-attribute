# frozen_string_literal: true

module MoneyAttribute
  module MigrationExtensions
    # Shared argument-parsing logic for migration helpers.
    #
    # Resolves accessor names, column overrides, and amount type configuration
    # into concrete column definitions. Included by both {SchemaStatements} and
    # {TableDefinition}.
    #
    # @!attribute [rw] AMOUNT_CONFIG
    #   @return [Hash{Symbol => Hash}] mapping of symbolic type names to
    #     column type/hash pairs
    # @!attribute [rw] CURRENCY_MIN_LIMIT
    #   @return [Integer] minimum allowed currency column string limit (8)
    # @!attribute [rw] CURRENCY_DEFAULT_LIMIT
    #   @return [Integer] default currency column string limit (20)
    module Helper
      AMOUNT_CONFIG = {
        crypto_decimal: { type: :decimal, precision: 36, scale: 18 },
        fiat_decimal: { type: :decimal, precision: 20, scale: 4 },
        fiat_integer: { type: :bigint }
      }.freeze

      CURRENCY_MIN_LIMIT = 8
      CURRENCY_DEFAULT_LIMIT = 20

      private

      # Parses arguments for a single-column (amount-only) migration.
      #
      # @param accessor [Symbol, String] the money attribute name
      # @param options [Hash] column options
      # @option options [Symbol] :column explicit column name override
      # @option options [Symbol] :type amount type (+:fiat_decimal+,
      #   +:crypto_decimal+, +:fiat_integer+)
      # @option options [Boolean] :null whether the column allows NULL
      # @option options [Object] :default default value for the column
      # @return [Array(String, Hash)] column name and merged options hash
      # @raise [ArgumentError] if +precision:+ or +scale:+ are given, or
      #   type is unrecognized
      # @api private
      def parse_money_amount_args(accessor, options)
        options ||= {}
        if options.key?(:precision) || options.key?(:scale)
          raise ArgumentError,
                'precision:/scale: are not configurable — money_attribute uses fixed, ' \
                'vetted values per type (:crypto_decimal, :fiat_decimal, :fiat_integer) ' \
                'to prevent under-precision bugs, particularly for crypto amounts.'
        end

        column = (options[:column] || accessor).to_s

        config = AMOUNT_CONFIG[options[:type] || :fiat_decimal]
        unless config
          raise ArgumentError, "Invalid type #{options[:type]}. Use :crypto_decimal, :fiat_decimal or :fiat_integer"
        end

        options = { null: options[:null], default: options[:default] }.compact
        [column, config.merge(options)]
      end

      # Parses arguments for the currency column in a composite migration.
      #
      # @param accessor [Symbol, String] the money attribute name
      # @param options [Hash] currency column options
      # @option options [Symbol] :column explicit currency column name override
      # @option options [Integer] :limit string limit for the column
      # @option options [Boolean] :null whether the column allows NULL
      # @option options [Object] :default default value for the column
      # @return [Array(String, Hash)] column name and merged options hash
      # @raise [ArgumentError] if limit is below {CURRENCY_MIN_LIMIT}
      # @api private
      def parse_currency_args(accessor, options)
        options ||= {}
        limit = (options[:limit] || CURRENCY_DEFAULT_LIMIT).to_i
        if limit < CURRENCY_MIN_LIMIT
          raise ArgumentError,
                "currency limit: #{limit} is too small to hold an ISO 4217 code and crypto popular codes" \
                "(minimum #{CURRENCY_MIN_LIMIT}). Omit limit: to use the default of #{CURRENCY_DEFAULT_LIMIT}, " \
                "or pass a value >= #{CURRENCY_MIN_LIMIT}."
        end

        column = currency_column_name(accessor, options[:column])
        [column, { limit:, null: options[:null], default: options[:default] }.compact]
      end

      # Resolves the currency column name for the given accessor.
      #
      # Resolution order:
      # 1. Explicit +column_override+ → returned as-is
      # 2. Accessor is +:amount+ → +currency+
      # 3. Accessor ends with +_amount+ → strips suffix and appends +_currency+
      # 4. Otherwise → +<accessor>_currency+
      #
      # @param accessor [Symbol, String] the money attribute name
      # @param column_override [Symbol, String, nil] explicit column name
      # @return [String] the resolved currency column name
      # @api private
      def currency_column_name(accessor, column_override)
        return column_override.to_s if column_override

        name = accessor.to_s
        return 'currency' if name == 'amount'

        radical = name.end_with?('_amount') ? name.sub(/_amount$/, '') : name
        "#{radical}_currency"
      end

      # Parses arguments for a composite (amount + currency) migration.
      #
      # Delegates to {#parse_money_amount_args} and {#parse_currency_args}
      # using the nested +:amount+ and +:currency+ option keys.
      #
      # @param accessor [Symbol, String] the money attribute name
      # @param options [Hash] migration options
      # @option options [Hash] :amount amount column options
      # @option options [Hash] :currency currency column options
      # @return [Array(String, String, Hash, Hash)] amount column name,
      #   currency column name, amount options, currency options
      # @api private
      def parse_money_args(accessor, options = {})
        amount_column, amount_options = parse_money_amount_args(accessor, options[:amount])
        currency_column, currency_options = parse_currency_args(accessor, options[:currency])

        [amount_column, currency_column, amount_options, currency_options]
      end
    end
  end
end
