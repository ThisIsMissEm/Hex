require 'lib/hex'
 
# Rack config
use Rack::Static, :urls => ['/css', '/js', '/images'], :root => "demo/public"
use Rack::CommonLogger
 
if ENV['RACK_ENV'] == 'development'
  use Rack::ShowExceptions
end
 
#
# Create and configure a hex instance
#
run Hex::Server.new
