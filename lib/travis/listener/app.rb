require 'sinatra'

module Travis
  module Listener
    class App < Sinatra::Base
      def service_supported?(service = params[:service])
        Payload.constants.any? { |n| n.to_s.downcase == service }
      end

      def token
        Rack::Auth::Basic::Request.new(env).credentials.last
      end

      post '/:service/:token' do
        pass unless service_supported?
        Request.create_from(request.body, token)
        204
      end
    end
  end
end