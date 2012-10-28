#### App Configs

configure do
  # s3 configs
  set :bucket, ENV['S3_BUCKET']
  set :s3_key, ENV['S3_KEY']
  set :s3_secret, ENV['S3_SECRET']
  set :base_link_url, ENV['BASE_LINK_URL'] # http://www.example.com/ note trailing slash
  
  # redis configs
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  
  # imgkit configs
  IMGKit.configure do |config|
    config.wkhtmltoimage = "#{settings.root}/bin/wkhtmltoimage-amd64"
  end
  
  if ENV['RACK_ENV'] == 'production'
    # airbrake configs
    Airbrake.configure do |config|
      config.api_key = ENV['AIRBRAKE_API_KEY']
    end
  
    # use airbrake errors
    use Airbrake::Rack
    enable :raise_errors
  end
end