# frozen_string_literal: true

module MoneyAttribute
  module Generators
    class InitializerGenerator < ::Rails::Generators::Base
      source_root File.expand_path('../templates', __dir__)

      desc 'Creates MoneyAttribute initializer.'

      def copy_initializer
        copy_file 'money_attribute.rb', 'config/initializers/money_attribute.rb'
      end
    end
  end
end
