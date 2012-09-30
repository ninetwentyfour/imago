%w(rubygems sinatra imgkit aws/s3 digest/md5 haml redis open-uri sinatra-initializers).each{ |g| require g }

set :bucket, 'screengrab-test'
set :s3_key, ENV['S3_KEY']
set :s3_secret, ENV['S3_SECRET']

uri = URI.parse(ENV["REDISTOGO_URL"])
redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

# register Sinatra::Initializers

# ?website=example.com&width=600&height=600
get '/?' do
  # take website and sizes as params (maybe jpg or png)
  
  # hash params to use as file name and key value
  
  # lookup a key first, if found return that
  
  # if not - go ahead and get the image 
  
  # save memcache or redis key for has with final image url
  
  # check for valid url
  
  # check that image exists or return some default not found with an error message 
  
  # move this into real config file
  # IMGKit.configure do |config|
  #   config.wkhtmltoimage = "#{settings.root}/bin/wkhtmltoimage-amd64"
  # end
  
  html = "http://#{params['website']}"
  name = Digest::MD5.hexdigest("#{params['website']}_#{params['width']}_#{params['height']}")
  @link = redis.get "#{name}"
  unless @link
    kit   = IMGKit.new(html, quality: 50, width: params['width'].to_i, height: params['height'].to_i )

    AWS::S3::Base.establish_connection!(
    :access_key_id     => settings.s3_key,
    :secret_access_key => settings.s3_secret)
    AWS::S3::S3Object.store("#{name}.png",kit.to_img(:png),settings.bucket,:access => :public_read)
  
    @link = "http://screengrab-test.s3.amazonaws.com/#{name}.png"
    redis.set "#{name}", @link
  end
  
  haml :main
end