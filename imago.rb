%w(rubygems sinatra sinatra-initializers imgkit aws/s3).each{ |g| require g }
# require 'aws/s3'

set :bucket, 'screengrab-test'
set :s3_key, ENV['S3_KEY']
set :s3_secret, ENV['S3_SECRET']
# register Sinatra::Initializers

get '/?' do
  IMGKit.configure do |config|
    config.wkhtmltoimage = "#{settings.root}/bin/wkhtmltoimage-amd64"
  end
  
  html = "http://google.com"
  kit   = IMGKit.new('http://google.com')
  #kit.to_file('./.tmp/test.png')
  AWS::S3::Base.establish_connection!(
  :access_key_id     => settings.s3_key,
  :secret_access_key => settings.s3_secret)
  AWS::S3::S3Object.store('test.png',kit.to_img(:png),settings.bucket,:access => :public_read)

  #puts "#{settings.root}/bin/wkhtmltoimage-amd64"
end