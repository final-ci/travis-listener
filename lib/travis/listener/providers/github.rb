module Travis
  module Listener
    module Provider

      class Github
        attr_accessor :env, :params
        def initialize(env, params, request)
          @env = env
          @params = params
        end

        def valid_request?
          payload
        end



        def name
          'github'
        end

        def data
          {
            :type => event_type,
            :credentials => credentials,
            :payload => payload,
            :uuid => uuid,
            :github_guid => delivery_guid,
            :github_event => event_type,
            :provider => name
          }
        end

        def each_ref
          yield data
        end

        def uuid
          env['HTTP_X_REQUEST_ID'] || Travis.uuid
        end

        def event_type
          env['HTTP_X_GITHUB_EVENT'] || 'push'
        end

        def event_details
          if event_type == 'pull_request'
            {
              number: decoded_payload['number'],
              action: decoded_payload['action'],
              source: decoded_payload['pull_request']['head']['repo'] && decoded_payload['pull_request']['head']['repo']['full_name'],
              head:   decoded_payload['pull_request']['head']['sha'][0..6],
              ref:    decoded_payload['pull_request']['head']['ref'],
              user:   decoded_payload['pull_request']['user']['login'],
            }
          elsif event_type == 'push'
            {
              ref:     decoded_payload['ref'],
              head:    push_head_commit,
              commits: (decoded_payload["commits"] || []).map {|c| c['id'][0..6]}.join(",")
            }
          end
        end

        def push_head_commit
          decoded_payload['head_commit'] && decoded_payload['head_commit']['id'] && decoded_payload['head_commit']['id'][0..6]
        end

        def delivery_guid
          env['HTTP_X_GITHUB_GUID']
        end

        def credentials
          login, token = Rack::Auth::Basic::Request.new(env).credentials
          { :login => login, :token => token }
        end

        def payload
          params[:payload]
        end

        def slug
          "#{owner_login}/#{repository_name}"
        end

        def owner_login
          decoded_payload['repository']['owner']['login'] || decoded_payload['repository']['owner']['name']
        end

        def repository_name
          decoded_payload['repository']['name']
        end

        def decoded_payload
          @decoded_payload ||= MultiJson.load(payload)
        end
      end
    end
  end
end

