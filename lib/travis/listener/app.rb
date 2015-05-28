require 'sinatra'
require 'travis/support/logging'
require 'sidekiq'
require 'travis/sidekiq/build_request'
require 'multi_json'
require 'ipaddr'
require 'metriks'

require 'travis/listener/providers/github'
require 'travis/listener/providers/stash'

module Travis
  module Listener
    class App < Sinatra::Base
      include Logging

      # use Rack::CommonLogger for request logging
      enable :logging, :dump_errors
      use Rack::CommonLogger, STDERR

      # see https://github.com/github/github-services/blob/master/lib/services/travis.rb#L1-2
      set :events, %w[push pull_request]

      before do
        logger.level = 1
      end

      get '/' do
        redirect "http://about.travis-ci.org"
      end

      # Used for new relic uptime monitoring
      get '/uptime' do
        200
      end

      # the main endpoint for scm services
      post '/' do
        set_provider('github')
        handle_request
      end

      post '/stash' do
        set_provider('stash')
        handle_request
      end

      #jenkins
      get '/git/notifyCommit' do
        # the only parametry is "ssl" saying git clone URI
      end

      protected

      def handle_request
        report_ip_validity
        if !ip_validation? || valid_ip?
          if valid_request?
            content_type :json
            jid = handle_event
            halt({ jid: jid }.to_json)
          else
            Metriks.meter('listener.request.no_payload').mark
            422
          end
        else
          403
        end
      end

      def valid_request?
        provider.valid_request?
      end

      def ip_validation?
        (Travis.config.listener && Travis.config.listener.ip_validation)
      end

      def report_ip_validity
        if valid_ip?
          Metriks.meter('listener.ip.valid').mark
        else
          Metriks.meter('listener.ip.invalid').mark
          logger.info "Payload to travis-listener sent from an invalid IP(#{request.ip})"
        end
      end

      def valid_ip?
        return true if valid_ips.empty?

        valid_ips.any? { |ip| IPAddr.new(ip).include? request.ip }
      end

      def valid_ips
        (Travis.config.listener && Travis.config.listener.valid_ips) || []
      end

      def set_provider(provider)
        @provider = ('travis/listener/provider/' + provider).camelize.constantize.new(env, params, request)
      end

      def provider
        @provider
      end

      def handle_event
        return unless handle_event?
        debug "Event payload for #{provider.uuid}: #{payload.inspect}, provider: #{provider}"
        log_event(event_details,
          uuid: provider.uuid,
          delivery_guid: provider.delivery_guid,
          provider: provider.name,
          type: event_type,
          repository: provider.slug
        )
        provider.each_ref do |data|
          Travis::Sidekiq::BuildRequest.perform_async(data)
        end
      end

      def handle_event?
        settings.events.include?(event_type)
      end

      def log_event(event_details, event_basics)
        info(event_details.merge(event_basics).map{|k,v| "#{k}=#{v}"}.join(" "))
      end

      def event_type
        provider.event_type
      end

      def event_details
        provider.event_details
      rescue => e
        error("Error logging payload: #{e.message}")
        error("Payload causing error: #{payload.inspect}")
        Raven.capture_exception(e) if defined?(Raven)
        {}
      end

      def payload
        provider.payload
      end

    end
  end
end
