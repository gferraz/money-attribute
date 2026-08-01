# frozen_string_literal: true

module MoneyAttribute
  # Converts raw attribute input into +Mint::Money+ values.
  #
  # Used in two roles: as the +:converter+ option of +composed_of+ (composite
  # attributes) and as the normalizer block for +money_amount+ (single-column
  # attributes). Accepts +Mint::Money+, numeric, string, and +nil+ input.
  class Converter
    DEFAULT = new.freeze

    # Initializes a converter with an optional fixed currency.
    #
    # @param currency [String, Symbol, Mint::Currency, nil] the currency to use
    #   for parsed values; falls back to {MoneyAttribute.default_currency} when nil
    # @return [Converter]
    def initialize(currency = nil)
      @static_currency = currency
    end

    # Returns the shared default converter instance.
    #
    # @return [Converter] the frozen, process-wide converter
    def self.default
      DEFAULT
    end

    # Converts raw input into a +Mint::Money+ value.
    #
    # @param amount [Mint::Money, Numeric, String, nil] the input value
    # @return [Mint::Money, nil] +Mint::Money+ for numeric and string input,
    #   the input itself for +Mint::Money+ and +nil+
    # @raise [ArgumentError] for unsupported input types
    def parse(amount)
      currency = @static_currency || MoneyAttribute.default_currency
      case amount
      when Money, NilClass      then amount
      when Numeric              then Money.from(amount, currency)
      when String               then Money.parse(amount, currency)
      else raise ArgumentError, "Cannot convert #{amount.inspect} (#{amount.class}) to Money"
      end
    end

    alias call parse
  end
end
