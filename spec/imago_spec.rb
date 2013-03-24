#
require File.join(File.dirname(__FILE__), '../imago.rb')
require 'rspec'
require 'rack/test'

set :environment, :test

describe 'Imago' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  describe 'validations' do
    
    it "validates good params" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '600',
        'height' => '600',
        'format' => 'json'
      }
      @errors = validate(params)
      @errors.should == {}
    end

    it "requires a website" do
      params = {
        'width' => '600',
        'height' => '600',
        'format' => 'json'
      }
      @errors = validate(params)
      @errors['website'].should == 'This field is required'
    end

    it "requires a non empty website" do
      params = {
        'website' => '',
        'width' => '600',
        'height' => '600',
        'format' => 'json'
      }
      @errors = validate(params)
      @errors['website'].should == 'This field is required'
    end
    
    it "requires a width" do
      params = {
        'website' => 'www.travisberry.com',
        'height' => '600',
        'format' => 'json'
      }
      @errors = validate(params)
      @errors['width'].should == 'This field is required'
    end

    it "requires a non empty width" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '',
        'height' => '600',
        'format' => 'json'
      }
      @errors = validate(params)
      @errors['width'].should == 'This field is required'
    end
    
    it "requires a height" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '600',
        'format' => 'json'
      }
      @errors = validate(params)
      @errors['height'].should == 'This field is required'
    end

    it "requires a non empty height" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '600',
        'height' => '',
        'format' => 'json'
      }
      @errors = validate(params)
      @errors['height'].should == 'This field is required'
    end

    it "requires a format" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '600',
        'height' => '600'
      }
      @errors = validate(params)
      @errors['format'].should == 'This field is required'
    end

    it "requires a non empty format" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '600',
        'height' => '600',
        'format' => ''
      }
      @errors = validate(params)
      @errors['format'].should == 'This field is required'
    end
    
  end    
    
  it "uploads a file to amazon s3" do
    file = './spec/thug_life.jpeg'
    send_to_s3(file, 'test_file').should_not be nil
  end
  
  it "returns a json response for a valid url" do
    get '/get_image?website=www.travisberry.com&width=320&height=200&format=json'
    last_response.should be_ok
    last_response.header["Content-Type"].should == "application/json;charset=utf-8"
    last_response.body.should == '{"link":"https://d29sc4udwyhodq.cloudfront.net/6b3927a0e37512e2efa3b25cb440a498.jpg","website":"http://www.travisberry.com"}'
  end
  
  it "returns an image response for a valid url" do
    get '/get_image?website=www.travisberry.com&width=320&height=200&format=image'
    last_response.should be_ok
    # puts last_response.header
    last_response.header.should == {"Content-Type"=>"image/jpeg", "Cache-Control"=>"max-age=2592000, no-transform, public", "Expires"=>"Thu, 29 Sep 2022 01:22:54 GMT+00:00", "X-Content-Type-Options"=>"nosniff", "Content-Length"=>"11107"}
  end
  
  it "returns a html response for a valid url" do
    get '/get_image?website=www.travisberry.com&width=320&height=200&format=html'
    last_response.should be_ok
    last_response.header["Content-Type"].should == "text/html;charset=utf-8"
  end
  
  it "returns a json response for a url with no format" do
    get '/get_image?website=www.travisberry.com&width=320&height=200'
    last_response.should be_ok
    last_response.header["Content-Type"].should == "application/json;charset=utf-8"
    last_response.body.should == '{"link":"https://d29sc4udwyhodq.cloudfront.net/not_found.jpg","website":"http://www.travisberry.com"}'
  end
end