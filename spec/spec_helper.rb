require 'simplecov'
SimpleCov.start

RSpec.configure do |config|
  config.color = true
end

Dir['./spec/support/**/*.rb'].each { |f| require f }
