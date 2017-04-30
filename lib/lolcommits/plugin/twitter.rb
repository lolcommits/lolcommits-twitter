require 'yaml'
require 'oauth'
require 'simple_oauth'
require 'rest_client'
require 'addressable/uri'
require 'lolcommits/plugin/base'

module Lolcommits
  module Plugin
    class Twitter < Base

      API_ENDPOINT    = 'https://api.twitter.com'.freeze
      CONSUMER_KEY    = 'qc096dJJCxIiqDNUqEsqQ'.freeze
      CONSUMER_SECRET = 'rvjNdtwSr1H0TvBvjpk6c4bvrNydHmmbvv7gXZQI'.freeze
      MAX_TWEET_CHARS = (139 - 24).freeze # (139 - reserved media chars)
      AUTH_PIN_REGEX  = /^\d{4,}$/ # 4 or more digits
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
      # process.
      #
      # @return [Array] the position(s), in this case after capture is ready
      #
      def self.runner_order
        [:captureready]
      end

      ##
      # Plugin is configured when the access token and secret exist
      #
      # @return [Boolean] true/false if this plugin has been configured
      #
      def configured?
        configuration['access_token'] && configuration['secret']
      end

      ##
      # Prompts the user to configure plugin options.
      # Enabled, Twitter auth, then prefix and suffix options.
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
      # Capture ready hook, runs after lolcommits captures a snapshot and the
      # image processing has completed
      #
      # Posts the lolcommit to Twitter
      #
      def run_captureready
        status = build_tweet(runner.message)

        begin
          puts "Tweeting: #{status}"
          debug "--> Tweeting! (length: #{status.length} chars)"
          post_tweet(status, File.open(runner.main_image, 'r'))
        rescue StandardError => e
          debug "Tweeting FAILED! #{e.class} - #{e.message}"
          puts "ERROR: Tweeting FAILED! - #{e.message}"
        end
      end


      private

      def post_url
        # TODO: this endpoint is deprecated, use the new approach instead
        # https://dev.twitter.com/rest/reference/post/statuses/update_with_mediath_media
        @post_url ||= API_ENDPOINT + '/1.1/statuses/update_with_media.json'
      end

      def post_tweet(status, media)
        RestClient.post(
          post_url,
          {
            'status'  => status,
            'media[]' => media
          }, Authorization: oauth_header
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
        print "\n2) Enter PIN, then press enter: "
        twitter_pin = gets.strip.downcase.to_s

        unless twitter_pin =~ AUTH_PIN_REGEX
          puts "\nERROR: '#{twitter_pin}' is not a valid Twitter Auth PIN"
          return
        end

        begin
          debug "Requesting Twitter OAuth Token with PIN: #{twitter_pin}"
          OAuth::RequestToken.new(oauth_consumer, rtoken, rsecret)
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
          'access_token' => access_token.token,
          'secret'       => access_token.secret
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

      def oauth_header
        @oauth_header ||= begin
          uri = Addressable::URI.parse(post_url)
          SimpleOAuth::Header.new(:post, uri, {}, oauth_credentials)
        end
      end

      def oauth_credentials
        {
          consumer_key: CONSUMER_KEY,
          consumer_secret: CONSUMER_SECRET,
          token: configuration['access_token'],
          token_secret: configuration['secret']
        }
      end

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
end
