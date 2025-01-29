require 'net/http'
require 'json'

module LLMs
  module APIs
    class GoogleGeminiAPI

      def initialize(api_key)
        @api_key = api_key
      end

      def generate_content(model_name, messages, params = {})
        stream = params.delete(:stream)

        path = "/#{model_name}:#{!!stream ? 'streamGenerateContent?alt=sse&' : 'generateContent?'}key=#{@api_key}"
        uri = URI("https://generativelanguage.googleapis.com/v1beta/models#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'

        request.body = params.merge({
          contents: messages
        }).to_json

        if stream
          http.request(request) do |response|
            if response.code.to_s == '200'
              response.read_body do |data|
                stream.call(data)
              end
              return nil ## return nil to indicate that there's no separate api response other than the stream
            else
              return JSON.parse(response.body)
            end
          end
        else
          response = http.request(request)
          JSON.parse(response.body)
        end
      end
    end
  end
end
