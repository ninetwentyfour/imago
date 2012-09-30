#### Requires

# Write out all requires from gems
%w(rubygems sinatra imgkit aws/s3 digest/md5 haml redis open-uri).each{ |g| require g }

# require the app configs
require_relative 'config'


#### GET /

# `/?` takes a list of params.
# The list of params are (all are required):
#
# * `website`: the url you wish to screenshot. Do not include http/https.
#    url should be encoded. (e.g. www.example.com)
#
# * `width`: the width of the screen shot. (e.g. 600)
#
# * `height`: the height of the screenshot. (e.g. 600)
#
# _EXAMPLE_:
#
# /?website=www.example.com&width=600&height=600
get '/get_image?' do
  
  @errors = validate(params)

  if @errors.empty?
    
  else
    
  end
  # make a way to reuturn either json or a straight image file - also do a for fun email image to person call
  
  # validate params
  # check for valid url
  
  # check that image exists or return some default not found with an error message 
  
  html = "http://#{params['website']}"
  
  # Hash the params to get the filename and the key for redis
  name = Digest::MD5.hexdigest("#{params['website']}_#{params['width']}_#{params['height']}")
  
  # Try to lookup the hash to see if this image has been created before
  @link = REDIS.get "#{name}"
  unless @link
    # Create the image.
    # should set a commen standard here, and resize later with passed params since this actually sets the browser viewport size
    begin
      kit   = IMGKit.new(html, quality: 50, width: params['width'].to_i, height: params['height'].to_i )
    
      # Store the image on s3.
      send_to_s3(kit.to_img(:png), name)
    
      # Create the link.
      @link = "http://screengrab-test.s3.amazonaws.com/#{name}.png"
    rescue Exception => exception
      @link = "http://screengrab-test.s3.amazonaws.com/not_found.png"
    end
    # Save in redis for re-use later.
    REDIS.set "#{name}", @link
  end
  
  # Render the main.haml view
  haml :main
end


def validate params
  errors = {}
  
  # if given? params[:website]
  #   errors[:website]   = "This is not solveable" unless solveable?(params[:bucket],params[:target])
  # else
  #   errors[:website]   = "This field is required"
  # end
  # 
  # if given? params[:width]
  #   errors[:width]   = "Please enter a valid email address" unless valid_email? params[:email]
  # end
  # 
  # if given? params[:height]
  #   errors[:width]   = "Please enter a valid email address" unless valid_email? params[:email]
  # end

  errors
end

# def valid_url?(url)
#   require "net/http"
#   url = URI.parse("http://www.google.com/")
#   req = Net::HTTP.new(url.host, url.port)
#   res = req.request_head(url.path)
#   res.code == "200"
# end

def send_to_s3(file, name)
  # Store the image on s3.
  AWS::S3::Base.establish_connection!(
                                      :access_key_id     => settings.s3_key,
                                      :secret_access_key => settings.s3_secret
                                    )
  AWS::S3::S3Object.store(
                            "#{name}.png",
                            file,
                            settings.bucket,
                            :access => :public_read
                          )
end