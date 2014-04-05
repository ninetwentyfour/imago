source 'http://bundler-api.herokuapp.com'
ruby "2.1.1"

gem "sinatra"
gem "shotgun"
gem "json"
gem "imgkit"
gem "fog"
gem "haml"
gem "redis"
gem "rmagick"
gem "json"
gem "newrelic_rpm"
gem "sinatra-jsonp"
gem "airbrake"
gem "connection_pool"
gem "unicorn"

group :development,:test do
  gem 'rspec'
  gem 'rack-test'
end

group :test do
  gem 'fakeredis'
	gem 'simplecov', :require => false
	gem 'coveralls', :require => false
end