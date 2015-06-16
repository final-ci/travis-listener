module Travis
  module Listener
    module Provider
      class Stash

        attr_accessor :env, :params, :request
        def initialize(env, params, request)
          @env = env
          @params = params
          @request = request
        end

        def valid_request?
          payload && decoded_payload['refChanges']
        end


        def name
          'stash'
        end

        def data
          {
            :type => event_type,
            :payload => payload,
            :uuid => uuid,
            :provider => name,

            # stash does not provide any users info,
            # therefore setting owner_name to project "owner"
            :owner_name => decoded_payload['repository']['project']['name'],
            :credentials => credentials
          }
        end

        def each_ref
          payload_ref_changes.map do |ref|
            yield data.update(payload: decoded_payload.update(refChange: ref).to_json)
          end
        end

        def credentials
          login, token = Rack::Auth::Basic::Request.new(env).credentials rescue nil
          { :login => login, :token => token }
        end

        def uuid
          env['HTTP_X_REQUEST_ID'] || Travis.uuid
        end

        def event_type
          'push'
        end

        def event_details
          {
            head:    push_head_commits,
            ref:     payload_ref_changes.map { |r| r['refId'] }.join(', '),
            slug:    slug,
            project: decoded_payload['repository']['project']
          }
        end

        def payload_ref_changes
          decoded_payload['refChanges']
        end


        def push_head_commits
          payload_ref_changes.map do |ref|
            ref['toHash'][0..6]
          end.join(', ')
        end

        def delivery_guid
          nil
        end

        def payload
          @payload ||= request.body.read
        end

        def slug
          "#{owner_slug}/#{repository_name}"
        end

        def owner_slug
          decoded_payload['repository']['project']['key']
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

