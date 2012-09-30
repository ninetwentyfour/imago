#### Requires

# Write out all requires from gems
%w(rubygems sinatra imgkit aws/s3 digest/md5 haml redis open-uri RMagick json).each{ |g| require g }

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
#    Use image to inline images (e.g. <img src="/get_image?format=image" />)
#
# _EXAMPLE_:
#
# /get_image?website=www.example.com&width=600&height=600&format=image
get '/get_image?' do
  
  @errors = validate(params)

  if @errors.empty?
    # make a way to reuturn either json or a straight image file - also do a for fun email image to person call

    html = "http://#{params['website']}"

    # Hash the params to get the filename and the key for redis
    name = Digest::MD5.hexdigest("#{params['website']}_#{params['width']}_#{params['height']}")

    # Try to lookup the hash to see if this image has been created before
    @link = REDIS.get "#{name}"
    unless @link
      begin
        # Create tmp directory if it doesn't exist
        temp_dir = "#{settings.root}/tmp"
        Dir.mkdir(temp_dir) unless Dir.exists?(temp_dir)
        
        # Capture the screenshot
        kit   = IMGKit.new(html, quality: 50, width: 1280, height: 720 )
        
        temp_file = "#{temp_dir}/#{name}.jpg"
        # Resize the screengrab using rmagick
        img = Image.from_blob(kit.to_img(:jpg)).first
        thumb = img.resize_to_fill(params['width'].to_i, params['height'].to_i)
        thumb.write temp_file

        # Store the image on s3.
        send_to_s3(temp_file, name)

        # Create the link.
        @link = "http://screengrab-test.s3.amazonaws.com/#{name}.jpg"
      rescue Exception => exception
        @link = "http://screengrab-test.s3.amazonaws.com/not_found.png"
      end
      # Save in redis for re-use later.
      REDIS.set "#{name}", @link
    end
  else
    @link = "http://screengrab-test.s3.amazonaws.com/not_found.png"
  end
  
  # Respond based on format
  if params['format'] == "html"
    haml :main
  elsif params['format'] == "json"
    content_type :json
    { :link => @link, :website => "http://#{params['website']}" }.to_json
  elsif params['format'] == "image" 
    uri = URI(@link)

    # get only header data
    head = Net::HTTP.start(uri.host, uri.port) do |http|
      http.head(uri.request_uri)
    end

    # set headers accordingly (all that apply)
    headers 'Content-Type' => head['Content-Type']

    # stream back the contents
    stream do |out|
      Net::HTTP.get_response(uri) do |f| 
        f.read_body { |ch| out << ch }
      end
    end
  end
end


def validate params
  errors = {}
  
  # Make sure the website is a passed in param.
  if !given? params['website']
    errors['website']   = "This field is required"
  end
  
  # Make sure the width is a passed in param.
  if !given? params['width']
    errors['width']   = "This field is required"
  end
  
  # Make sure the height is a passed in param.
  if !given? params['height']
    errors['height']   = "This field is required"
  end
  
  # Make sure the format is a passed in param.
  if !given? params['format']
    errors['format']   = "This field is required"
  end

  errors
end

def given? field
  !field.empty?
end

def send_to_s3(file, name)
  # Store the image on s3.
  AWS::S3::Base.establish_connection!(
                                      :access_key_id     => settings.s3_key,
                                      :secret_access_key => settings.s3_secret
                                    )
  AWS::S3::S3Object.store(
                            "#{name}.jpg",
                            open(file),
                            settings.bucket,
                            :access => :public_read
                          )
end