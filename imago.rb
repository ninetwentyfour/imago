%w(rubygems sinatra imgkit aws/s3 digest/md5 haml redis open-uri).each{ |g| require g }

require_relative 'config'

# ?website=example.com&width=600&height=600
get '/?' do
  # take website and sizes as params (maybe jpg or png)
  
  # hash params to use as file name and key value
  
  # lookup a key first, if found return that
  
  # if not - go ahead and get the image 
  
  # save memcache or redis key for has with final image url
  
  # check for valid url
  
  # check that image exists or return some default not found with an error message 
  
  html = "http://#{params['website']}"
  name = Digest::MD5.hexdigest("#{params['website']}_#{params['width']}_#{params['height']}")
  @link = REDIS.get "#{name}"
  unless @link
    kit   = IMGKit.new(html, quality: 50, width: params['width'].to_i, height: params['height'].to_i )

    AWS::S3::Base.establish_connection!(
    :access_key_id     => settings.s3_key,
    :secret_access_key => settings.s3_secret)
    AWS::S3::S3Object.store("#{name}.png",kit.to_img(:png),settings.bucket,:access => :public_read)
  
    @link = "http://screengrab-test.s3.amazonaws.com/#{name}.png"
    REDIS.set "#{name}", @link
  end
  
  haml :main
end