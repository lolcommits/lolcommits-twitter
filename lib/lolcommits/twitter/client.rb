# frozen_string_literal: true

require 'oauth'
require 'simple_oauth'
require 'rest_client'
require 'addressable/uri'

module Lolcommits
  module Twitter
    class Client

      API_ENDPOINT     = 'https://api.twitter.com'.freeze
      UPLOAD_ENDPOINT  = 'https://upload.twitter.com'.freeze
      CONSUMER_KEY     = 'CwMCjbxREk5dSloZeR5Uhb1Fe'.freeze
      CONSUMER_SECRET  = 'UfgIvD32rRgSwIWZq9hjADMYd0e3ax9FluSEePSNOqgmSCerU5'.freeze

      CHUNK_SIZE_BYTES = 5_000_000
      MAX_TWEET_CHARS  = (140 - 1 - 24).freeze # (140 - space - reserved media chars)

      def self.oauth_consumer
        OAuth::Consumer.new(
          CONSUMER_KEY,
          CONSUMER_SECRET,
          site: API_ENDPOINT,
          request_endpoint: API_ENDPOINT,
          sign_in: true
        )
      end

      def initialize(token, token_secret)
        @oauth_credentials = {
          consumer_key: CONSUMER_KEY,
          consumer_secret: CONSUMER_SECRET,
          token: token,
          token_secret: token_secret
        }
      end

      # @see https://dev.twitter.com/rest/reference/post/statuses/update
      def update_status(status, media_ids: [])
        url = API_ENDPOINT + "/1.1/statuses/update.json"
        post(url, params: { status: status, media_ids: media_ids })
      end

      # @see https://dev.twitter.com/rest/public/uploading-media
      def upload_media(media)
        response = begin
          # upload animated gifs in 5MB chunks
          if File.basename(media) =~ /\.gif$/
            upload_media_chunked(media)
          else
            post(upload_url, payload: { media: media })
          end
        end
        response['media_id_string']
      end

      # @see https://dev.twitter.com/rest/public/uploading-media
      def upload_media_chunked(media)
        media_id = upload('INIT', {
          media_type: 'image/gif',
          media_category: 'tweet_gif',
          total_bytes: media.size
        })['media_id_string']

        until media.eof?
          seg ||= -1
          base64_chunk = Base64.encode64(media.read(CHUNK_SIZE_BYTES))
          base64_chunk.delete("\n")
          upload('APPEND', {
            media_id: media_id,
            segment_index: seg += 1,
            media_data: base64_chunk
          })
        end
        media.close

        finalize = upload('FINALIZE', media_id: media_id)

        # check STATUS if this is an async media upload
        # @see https://dev.twitter.com/rest/reference/get/media/upload-status
        processing = finalize['processing_info']
        if processing
          until processing['state'] == 'succeeded'
            sleep processing['check_after_secs'] || 0.5
            processing = upload_status(media_id)['processing_info']
          end
        end

        finalize
      end


      private

      attr_reader :oauth_credentials

      def upload_url
        @upload_url ||= UPLOAD_ENDPOINT + "/1.1/media/upload.json"
      end

      # @see https://dev.twitter.com/rest/public/uploading-media
      def upload(command, payload = {})
        post(upload_url, payload: payload.merge(command: command))
      end

      # @see https://dev.twitter.com/rest/reference/get/media/upload-status
      def upload_status(media_id)
        get(upload_url, params: { command: 'STATUS', media_id: media_id })
      end

      def get(url, params: {})
        uri = Addressable::URI.parse(url)
        uri.query_values = params

        RestClient.get(uri.to_s, { Authorization: oauth_auth_header(uri) }) do |response, request, result|
          handle_response(response)
        end
      end

      def post(url, params: {}, payload: {})
        uri = Addressable::URI.parse(url)
        uri.query_values = params

        payload = payload.merge!(multipart: true) unless payload.empty?

        RestClient.post(uri.to_s, payload, Authorization: oauth_auth_header(uri, :post)) do |response, request, result|
          handle_response(response)
        end
      end

      def handle_response(response)
        return if response.empty? && response.code.to_s =~ /^2/ # an empty OK response

        parsed_response = JSON.parse(response)
        if response.code.to_s =~ /^2/
          return parsed_response
        else
          error_message = 'request failed'
          errors = parsed_response['errors']
          if errors
            error_message = errors.map { |err| "Error #{err['code']}: #{err['message']}" }.join(',')
          end
          raise StandardError.new(error_message)
        end
      end

      def oauth_auth_header(url, method = :get)
        uri = Addressable::URI.parse(url)
        SimpleOAuth::Header.new(method, uri, {}, oauth_credentials)
      end
    end
  end
end
