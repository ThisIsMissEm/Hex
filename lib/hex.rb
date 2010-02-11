require 'rack'
require 'yaml'
require 'rdiscount'
require 'erb'
require 'json/pure'


module Hex
  Paths = {
    :templates => "demo/templates",
    :data => "demo/data"
  }
  
  def self.env
    ENV['RACK_ENV'] || "production"
  end
  
  def self.env= env
    ENV['RACK_ENV'] = env
  end
  
  module Template
    def to_html
      ERB.new(File.read("#{Paths[:templates]}/layout.erb")).result(binding)
    end
  end
  
  class Site
    def initialize config
      @config = config
    end
    
    def route request
      return [400, "text/html", []] unless request.get?
      
      path, mime = request.path_info.split('.')
      route = (path || '/').split('/').reject {|i| i.empty? }
      
      if route.empty?
        route = [@config[:root]]
      end
      
      @page = Page.new(File.new("#{Paths[:data]}/#{route.join('/')}.md"))
      
      [200, "text/html", @page.to_html]
    end
  end
  
  class Page < Hash
    include Template
    
    def initialize obj
      @obj = obj
      
      if @obj.is_a? File
        self[:meta], self[:body] = @obj.read.split(/\n\n/, 2)
        @obj.close
      end
    end
    
    def meta
      YAML.load self[:meta]
    end
    
    def body
      RDiscount.new(self[:body]).to_html
    end
  end
  
  
  class Config < Hash
    Defaults = {
      :root => "index", # site index
      :url => "http://127.0.0.1",
      :markdown => :smart, # use markdown
      :ext => 'md', # extension for articles
      :cache => 28800, # cache duration (seconds)
    }

    def initialize config
      self.update Defaults
      self.update config
    end

    def set key, val
      if val.is_a? Hash
        self[key].update val
      else
        self[key] = val
      end
    end

    def [] key, *args
      val = super(key)
      val.respond_to?(:call) ? val.call(*args) : val
    end
  end
  
  class Server
    def initialize config
      @config = config.is_a?(Config) ? config : Config.new(config);
    end
    
    def call env
      @request = Rack::Request.new env
      @response = Rack::Response.new
      
      status, mime, body = Hex::Site.new(@config).route(@request)
      
      @response.body = body
      @response['Content-Type'] = mime
      @response.status = status
      @response.finish
    end
  end
end


