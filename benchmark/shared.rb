# frozen_string_literal: true

# Shared setup for all three benchmark sides (money_attribute, plain, money-rails).

require 'rails'
require 'active_record'
require 'sqlite3'

db_path = File.expand_path('../test/dummy/storage/test.sqlite3', __dir__)
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: db_path
)

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end

AMOUNT = BigDecimal('123456789.01')
CURRENCY_CODE = 'USD'
AMOUNT_SUBUNITS = 123_456_78901
AMOUNT_ALT = AMOUNT + 1
ALT_SUBUNITS = 123_556
NUM_RECORDS = 1_000
ITERATIONS = 5_000
MULTI_RECORD_COUNT = 2000
MULTI_RECORD_ITERATIONS = 1000
RECORDS_SAMPLE = [50, 500, 5000, 50_000]
FORMAT_ITERATIONS = 10_000
