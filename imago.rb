#### Requires

# Write out all requires from gems
%w(rubygems sinatra imgkit aws/s3 digest/md5 haml redis open-uri RMagick json airbrake newrelic_rpm sinatra/jsonp).each{ |g| require g }

# require the app configs
require_relative 'config'
include Magick

#### GET /get_image?

# `/get_image?` takes a list of params.
# The list of params are (all are required):
#
# * `website`: the url you wish to screenshot. Do not include http/https.
#    url should be encoded. (e.g. www.example.com)
#
# * `width`: the width of the screen shot. (e.g. 600)
#
# * `height`: the height of the screenshot. (e.g. 600)
#
# * `format`: the format to respond with. Accepted values are html, json, and image.
#    Use image to inline images (e.g. `<img src="/get_image?format=image" />`)
#
# _EXAMPLE_:
#
# /get_image?website=www.example.com&width=600&height=600&format=image
get '/get_image?' do
  
  @errors = validate(params)

  if @errors.empty?
    # Hash the params to get the filename and the key for redis
    name = Digest::MD5.hexdigest("#{params['website']}_#{params['width']}_#{params['height']}")

    # Try to lookup the hash to see if this image has been created before
    @link = REDIS.get "#{name}"
    unless @link
      begin
        url = "http://#{params['website']}"
        
        # Generate the image.
        img = generate_image(url)

        # Store the image on s3.
        send_to_s3(img, name)
        
        # Create the link url.
        @link = "#{settings.base_link_url}#{name}.jpg"
      rescue Exception => exception
        logger.error "Rescued Error Creating and Uploading Image: #{exception}"
        @link = "#{settings.base_link_url}not_found.jpg"
      end
      # Save in redis for re-use later.
      REDIS.set "#{name}", @link
      REDIS.expire "#{name}", 1209600
    end
  else
    logger.info "Setting link to not found because of bad params: #{@errors.inspect}"
    @link = "#{settings.base_link_url}not_found.jpg"
  end

  respond(@link, params)
end

#### respond
#
# * `link`: the final link to the image.
#
# * `params`: the params that were sent with the request.
#
# Respond to request
def respond(link, params)
  @link = link
  if params['format']
    # Respond based on format
    if params['format'] == "html"
      haml :main
    elsif params['format'] == "json"
      content_type :json
      data = { :link => @link, :website => "http://#{params['website']}" }
      JSONP data      # JSONP is an alias for jsonp method
    elsif params['format'] == "image"
      # TODO do all of this in a begin block. Do a send_file with a local copy of not found if fail
      @link = @link.sub("https://", 'http://')
      uri = URI(@link)

      # get only header data
      head = Net::HTTP.start(uri.host, uri.port) do |http|
        http.head(uri.request_uri)
      end

      # set headers accordingly (all that apply)
      headers 'Content-Type' => head['Content-Type']
      headers 'Cache-Control' => "max-age=2592000, no-transform, public"
      headers 'Expires' => "Thu, 29 Sep 2022 01:22:54 GMT+00:00"

      # stream back the contents
      stream do |out|
        Net::HTTP.get_response(uri) do |f| 
          f.read_body { |ch| out << ch }
        end
      end
    end
  else
    # Default to json if no format.
    content_type :json
    data = { :link => @link, :website => "http://#{params['website']}" }
    JSONP data      # JSONP is an alias for jsonp method
  end
end

#### validate
#
# * `params`: the params that were sent with the request.
#
# Validate the params sent with the request.
def validate(params)
  errors = {}
  
  # Make sure the website is a passed in param.
  unless params['website'] && given?(params['website'])
    errors['website']   = "This field is required"
  end
  
  # Make sure the width is a passed in param.
  unless params['width'] && given?(params['width'])
    errors['width']   = "This field is required"
  end
  
  # Make sure the height is a passed in param.
  unless params['height'] && given?(params['height'])
    errors['height']   = "This field is required"
  end
  
  # Make sure the format is a passed in param.
  unless params['format'] && given?(params['format'])
    errors['format']   = "This field is required"
  end

  errors
end

#### given?
#
# * `field`: the param field to check.
#
# Check that a field is not empty
def given?(field)
  !field.empty?
end

#### send_to_s3
#
# * `file`: the tmp path to the image file.
#
# * `name`: the name to use for the file.
#
# Store the image on s3.
def send_to_s3(img, name)
  AWS::S3::Base.establish_connection!(
                                      :access_key_id     => settings.s3_key,
                                      :secret_access_key => settings.s3_secret
                                     )
  AWS::S3::S3Object.store(
                            "#{name}.jpg",
                            img,
                            settings.bucket,
                            :access => :public_read
                          )
end

#### generate_image
#
# * `url`: the url of the website to thumbnail. (http://www.example.com)
#
# Grab the website image, resize with rmagick and return the image blob.
def generate_image(url)
  # Capture the screenshot
  kit   = IMGKit.new(url, quality: 90, width: 1280, height: 720 )

  # Resize the screengrab using rmagick
  img = Image.from_blob(kit.to_img(:jpg)).first
  # img.sample!(params['width'].to_i, params['height'].to_i)
  img.thumbnail!(params['width'].to_i, params['height'].to_i)
  # img.resize_to_fill!(params['width'].to_i, params['height'].to_i)
  img.to_blob
end
