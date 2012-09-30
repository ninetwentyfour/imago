%w(rubygems sinatra sinatra-initializers imgkit).each{ |g| require g }

# register Sinatra::Initializers

get '/?' do
  IMGKit.configure do |config|
    config.wkhtmltoimage = "#{settings.root}/bin/wkhtmltoimage-amd64"
  end
  
  html = "http://google.com"
  kit   = IMGKit.new('http://google.com')
  kit.to_file('./test.png')

  #puts "#{settings.root}/bin/wkhtmltoimage-amd64"
end