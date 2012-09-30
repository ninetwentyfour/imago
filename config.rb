configure do
  set :bucket, 'screengrab-test'
  set :s3_key, ENV['S3_KEY']
  set :s3_secret, ENV['S3_SECRET']

  uri = URI.parse(ENV["REDISTOGO_URL"])
  redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  
  IMGKit.configure do |config|
    config.wkhtmltoimage = "#{settings.root}/bin/wkhtmltoimage-amd64"
  end
end