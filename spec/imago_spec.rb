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

    it "validates params" do
      params = {
        'website' => 'www.travisberry.com',
        'width' => '600',
        'height' => '600',
        'format' => 'json'
      }
      @errors = validate(params)
      @errors.should == {}
    end
    
    
    it "uploads a file to amazon s3" do
      file = './spec/thug_life.jpeg'
      send_to_s3(file, 'test_file').should_not be nil
    end
    
    it "returns a json response for a valid url" do
      get '/get_image?website=www.travisberry.com&width=320&height=200&format=json'
      last_response.should be_ok
      last_response.body.should == '{"link":"http://d29sc4udwyhodq.cloudfront.net/6b3927a0e37512e2efa3b25cb440a498.jpg","website":"http://www.travisberry.com"}'
    end
    
    it "returns a image response for a valid url" do
      get '/get_image?website=www.travisberry.com&width=320&height=200&format=image'
      last_response.should be_ok
      last_response.header.should =~ {"Content-Type"=>"image/jpeg"}
    end
end