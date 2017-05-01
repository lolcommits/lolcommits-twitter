require 'yaml'
require 'lolcommits/plugin/base'

require 'oauth'
require 'simple_oauth'
require 'rest_client'
require 'addressable/uri'

module Twitter
  module Oauth

    API_ENDPOINT    = 'https://api.twitter.com'.freeze
    UPLOAD_ENDPOINT = 'https://upload.twitter.com'.freeze
    CONSUMER_KEY    = 'CwMCjbxREk5dSloZeR5Uhb1Fe'.freeze
    CONSUMER_SECRET = 'UfgIvD32rRgSwIWZq9hjADMYd0e3ax9FluSEePSNOqgmSCerU5'.freeze

    def oauth_consumer
      @oauth_consumer ||= OAuth::Consumer.new(
        CONSUMER_KEY,
        CONSUMER_SECRET,
        site: API_ENDPOINT,
        request_endpoint: API_ENDPOINT,
        sign_in: true
      )
    end
  end
end

module Twitter
  class Client
    include Oauth

    CHUNK_SIZE_BYTES = 5_000_000

    def initialize(token, token_secret)
      @token = token
      @token_secret = token_secret
    end

    # @see https://dev.twitter.com/rest/reference/post/statuses/update
    def update_status(status, media_ids: [])
      url = API_ENDPOINT + "/1.1/statuses/update.json"
      post(url, params: { status: status, media_ids: media_ids })
      # TODO: show URL in output response['id_str']
    end


    # @see https://dev.twitter.com/rest/public/uploading-media
    def upload_media(media)
      response = begin
        if File.basename(media) =~ /\.gif$/
          # upload animated gifs in 5MB chunks
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

    attr_reader :token, :token_secret

    def upload_url
      @upload_url ||= UPLOAD_ENDPOINT + "/1.1/media/upload.json"
    end

    def upload(command, payload = {})
      post(upload_url, payload: payload.merge(command: command))
    end

    def upload_status(media_id)
      get(UPLOAD_ENDPOINT + "/1.1/media/upload.json", params: {
        command: 'STATUS', media_id: media_id
      })
    end

    def get(url, params: {})
      uri = Addressable::URI.parse(url)
      uri.query_values = params
      RestClient.get(uri.to_s, { Authorization: oauth_auth_header(uri, :get) }) do |response, request, result|
        return if response.empty? and result.code =~ /^2/ # an empty OK response
        JSON.parse(response)
      end
    end

    def post(url, params: {}, payload: {})
      uri = Addressable::URI.parse(url)
      uri.query_values = params

      payload = payload.merge!(multipart: true) unless payload.empty?

      RestClient.post(uri.to_s, payload, Authorization: oauth_auth_header(uri)) do |response, request, result|
        return if response.empty? and result.code =~ /^2/ # an empty OK response

        parsed_response = JSON.parse(response)
        if result.code =~ /^2/
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
    end

    def oauth_auth_header(url, method = :post)
      uri = Addressable::URI.parse(url)
      SimpleOAuth::Header.new(method, uri, {}, oauth_credentials)
    end

    def oauth_credentials
      {
        consumer_key: CONSUMER_KEY,
        consumer_secret: CONSUMER_SECRET,
        token: token,
        token_secret: token_secret
      }
    end
  end
end


module Lolcommits
  module Plugin
    class Twitter < Base
      include ::Twitter::Oauth

      MAX_TWEET_CHARS = (139 - 24).freeze # (139 - reserved media chars)
      DEFAULT_SUFFIX  = '#lolcommits'.freeze

      ##
      # Returns the name of the plugin. Identifies the plugin to lolcommits.
      #
      # @return [String] the plugin name
      #
      def self.name
        'twitter'
      end

      ##
      # Returns position(s) of when this plugin should run during the capture
      # process. We want to post to Twitter when the capture is ready.
      #
      # @return [Array] the position(s)
      #
      def self.runner_order
        [:captureready]
      end

      ##
      # Plugin is configured when a token and token secret exist
      #
      # @return [Boolean] true/false if the plugin has been configured
      #
      def configured?
        configuration['token'] && configuration['token_secret']
      end

      ##
      # Prompts the user to configure plugin options.
      # Options are enabled (true/false), Twitter auth, and prefix/suffix text.
      #
      # @return [Hash] a hash of configured plugin options
      #
      def configure_options!
        options = super
        # ask user to configure tokens (if enabling)
        if options['enabled']
          auth_config = configure_auth!
          return unless auth_config
          options = options.merge(auth_config).merge(configure_prefix_suffix)
        end
        options
      end

      ##
      # Capture ready hook, runs after lolcommits captures a snapshot and image
      # processing has completed.
      #
      # Posts the lolcommit to Twitter, first uploading the capture media, then
      # posting a new Tweet with the media_id attached.
      #
      def run_captureready
        status = build_tweet(runner.message)
        file   = File.open(runner.main_image, 'rb')

        puts "Tweeting"

        begin
          debug "--> Uploading media (#{file.size} bytes)"
          media_id = twitter_client.upload_media(file)
          debug "--> Posting status update (#{status.length} chars, media_id: #{media_id})"
          twitter_client.update_status(status, media_ids: [media_id])
          # TODO: puts URL to tweet on stdout
        rescue StandardError => e
          puts "ERROR: Tweeting FAILED! - #{e.message}"
        end
      end

      private

      def twitter_client
        @twitter_client ||= ::Twitter::Client.new(
          configuration['token'], configuration['token_secret']
        )
      end

      def build_tweet(commit_message)
        prefix = configuration['prefix'].to_s
        suffix = configuration['suffix'].to_s
        suffix = " #{configuration['suffix']}" unless suffix.empty?

        available_commit_msg_size = MAX_TWEET_CHARS - (prefix.length + suffix.length)
        if commit_message.length > available_commit_msg_size
          commit_message = "#{commit_message[0..(available_commit_msg_size - 3)]}..."
        end

        "#{prefix}#{commit_message}#{suffix}"
      end

      def configure_auth!
        puts '---------------------------------------'
        puts 'OK, we need to setup Twitter Auth first'
        puts '---------------------------------------'

        request_token = oauth_consumer.get_request_token
        rtoken        = request_token.token
        rsecret       = request_token.secret

        print "\n1) Please open this url in your browser to get a PIN for lolcommits:\n\n"
        puts request_token.authorize_url
        # TODO: use launchy (in lolcommits) to auto open this URL on supported
        # platforms
        print "\n2) Enter PIN, then press enter: "
        twitter_pin = gets.strip.downcase.to_s

        begin
          debug "Requesting Twitter OAuth Token with PIN: #{twitter_pin}"
          access_token = request_token.get_access_token(oauth_verifier: twitter_pin)
        rescue OAuth::Unauthorized
          puts "\nERROR: Twitter PIN Auth FAILED!"
          return
        end

        return unless access_token.token && access_token.secret

        puts ''
        puts '------------------------------'
        puts 'Thanks! Twitter Auth Succeeded'
        puts '------------------------------'

        {
          'token'        => access_token.token,
          'token_secret' => access_token.secret
        }
      end

      def configure_prefix_suffix
        print "\n3) Prefix all tweets with something? e.g. @user (default: nothing): "
        prefix = gets.strip
        print "\n4) End all tweets with something? e.g. #hashtag (default: #{DEFAULT_SUFFIX}): "
        suffix = gets.strip

        config = {}
        config['prefix'] = prefix.empty? ? '' : prefix
        config['suffix'] = suffix.empty? ? DEFAULT_SUFFIX : suffix
        config
      end
    end
  end
end
