require 'rack'
require 'yaml'
require 'rdiscount'
require 'digest'
require 'erb'


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
  
  class Site
    def initialize config
      @config = config
    end
    
    def route request
      return respond(400, "400 unsupported") unless request.get?
      
      path, mime = request.path_info.split('.')
      route = (path || '/').split('/').reject {|i| i.empty? }
      
      route << @config[:root] if route.empty?
      
      body = Page.new(route, @config).to_html
      
    rescue Errno::ENOENT => e
      respond(404, "404 not found")
    else
      respond(200, body)
    end
    
    def respond status, body, mime="text/html", args={}
      headers = args.merge({
        "Content-Type" => mime,
        "Content-Length" => body.length
      })
      
      headers["Content-Length"] = headers["Content-Length"].to_s
      
      return [status, headers, body];
    end
  end
  
  class Page < Hash
    def initialize route, config
      path = "#{Paths[:data]}/#{route.join('/')}";
      
      if !config[:ext].nil?
        path += config[:ext]
      elsif config[:syntax] == "html"
        path += ".html";
      elsif config[:syntax] == "markdown"
        path += ".md"
      else
        path += ".txt"
      end
      
      file = File.new(path)
      @raw_data = file.read
      file.close
            
      @meta, @body = if config[:syntax] == "markdown"
        Parser::Markdown.new(@raw_data).parse
      elsif config[:syntax] == "html"
        Parser::HTML.new(@raw_data).parse
      else
        [{"title" => route.join("/")}, @raw_data]
      end
      
      if !@meta["template"].nil?
        @template = @meta["template"].to_s
      elsif !config[:layout].nil?
        @template = config[:layout]
      else
        @template = "layout"
      end
    end
    
    def to_html
      ERB.new(File.read("#{Paths[:templates]}/#{@template}.erb")).result(binding)
    end
  end
  
  module Parser
    class Markdown < Hash
      def initialize data
        @data = data
      end
      def parse
        meta, body = @data.split(/\n\n/, 2)
      
        [YAML.load(meta), RDiscount.new(body).to_html]
      end
    end
    
  end
  
  class Config < Hash
    Defaults = {
      :root => "index", # site index
      :url => "http://127.0.0.1",
      :syntax => "markdown", # use markdown
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
    def initialize config={}
      @config = config.is_a?(Config) ? config : Config.new(config);
    end
    
    def call env
      @request = Rack::Request.new env
      @response = Rack::Response.new
      
      status, headers, body = Hex::Site.new(@config).route(@request)
      
      @response.body = [body] # weird bug on Archlinux means I need to pass body as an array.
      headers.each {|key, value| @response[key] = value}
      
      @response['Cache-Control'] = if Hex.env == 'production'
        "public, max-age=#{@config[:cache]}"
      else
        "no-cache, must-revalidate"
      end
 
      @response['Etag'] = Digest::SHA1.hexdigest(body)
      
      @response.status = status
      @response.finish
    end
  end
end


