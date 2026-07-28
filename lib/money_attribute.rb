# frozen_string_literal: true

# MoneyAttribute provides ActiveRecord integrations for the Minting money gem.
#
# Two storage modes:
#
# - +money_attribute :price+ — composite (amount + currency columns)
# - +money_amount :price+    — single column (fixed currency)
#
# @see MoneyAttribute::Macro
# @see MoneyAttribute::MoneyAmount

require 'minting'
require 'money_attribute/core_ext/numeric'
require 'money_attribute/core_ext/string'
require 'money_attribute/configuration'
require 'money_attribute/current'
require 'money_attribute/attribute_spec'
require 'money_attribute/attribute_spec_registry'
require 'money_attribute/macro'
require 'money_attribute/money_amount'
require 'money_attribute/converter'
require 'money_attribute/type'
require 'money_attribute/form_builder_extension'
require 'money_attribute/query'
require 'money_attribute/railtie'
require 'money_attribute/version'
