require 'net/http'
require 'json'

module LLMs
  module APIs
    class OpenAICompatibleAPI
      def initialize(api_key, base_url)
        @api_key = api_key
        @base_url = base_url
      end

      def chat_completion(model_name, messages, params = {})
        uri = URI("#{@base_url}/chat/completions")

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = @base_url.start_with?('https://')
        http.read_timeout = 1000

        stream = params.delete(:stream)
        params[:stream] = !!stream

        request = Net::HTTP::Post.new(uri).tap do |req|
          req['Content-Type'] = 'application/json'
          req['Authorization'] = "Bearer #{@api_key}"
          req.body = params.merge({
            model: model_name,
            messages: messages,
          }).to_json
        end

        if !!stream
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
          if response.code.to_s == '200'
            JSON.parse(response.body)
          else
            {'error' => JSON.parse(response.body)} ## TODO add status code?
          end
        end
      end

    end
  end
end
