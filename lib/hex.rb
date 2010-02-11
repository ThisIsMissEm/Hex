require 'yaml'
require 'erb'
require 'rack'

module Hex
  class Site
  end
  
  class Server
    def initialize
    end
    
    def call env
      @request = Rack::Request.new env
      @response = Rack::Response.new
      
      return [400, {}, []] unless @request.get?
      
      path, filetype = @request.path_info.split('.')
      
      @response.body = ["path"]
      @response['Content-Length'] = 4.to_s
      @response.status = 200
      @response.finish
    end
  end
end


