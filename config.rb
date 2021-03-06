###### App Configs

configure do
  # s3 configs
  set :bucket, ENV['IMAGO_S3_BUCKET']
  set :s3_key, ENV['IMAGO_S3_KEY']
  set :s3_secret, ENV['IMAGO_S3_SECRET']
  set :base_link_url, ENV['IMAGO_BASE_LINK_URL'] # http://abc.com/ - note trailing slash
  
  # redis configs
  if ENV['REDISTOGO_URL']
    uri = URI.parse(ENV['REDISTOGO_URL'])
    $redis ||= ConnectionPool.new(size: 5, timeout: 5) {
      Redis.new(host: uri.host, port: uri.port, password: uri.password) 
    }
  else
    $redis ||= ConnectionPool.new(size: 5, timeout: 5) { Redis.new }
  end
  
  # imgkit configs
  IMGKit.configure do |config|
    config.wkhtmltoimage = "#{settings.root}/bin/wkhtmltoimage-amd64"
  end
  
  # airbrake configs
  if ENV['RACK_ENV'] == 'production' && ENV['AIRBRAKE_API_KEY'] != nil
    Airbrake.configure do |config|
      config.api_key = ENV['AIRBRAKE_API_KEY']
    end
    use Airbrake::Rack
    enable :raise_errors
  end
end
