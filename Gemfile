source "https://rubygems.org"

ruby "3.3.11"

gem "rails", "~> 7.1.5"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"

gem "redis", ">= 4.0.1"
gem "sidekiq", "~> 7.2"
gem "prawn", "~> 2.5"
gem "prawn-table", "~> 0.2.2"
gem "csv"

gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "dotenv-rails", groups: [:development, :test]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails"
end

group :development do
  gem "web-console"
end
