# frozen_string_literal: true

require 'lolcommits/plugin/base'
require 'lolcommits/cli/launcher'
require 'lolcommits/twitter/client'

module Lolcommits
  module Plugin
    class Twitter < Base

      DEFAULT_SUFFIX  = '#lolcommits'.freeze

      ##
      # Indicate if the plugin is configured correctly.
      #
      # @return [Boolean] true/false
      #
      def valid_configuration?
        !!(configuration[:token] && configuration[:token_secret])
      end

      ##
      # Prompts the user to configure plugin options.
      # Options are enabled (true/false), Twitter auth, and prefix/suffix text.
      #
      # @return [Hash] a hash of configured plugin options
      #
      def configure_options!
        options = super
        # ask user to configure all options (if enabling)
        if options[:enabled]
          auth_config = configure_auth!
          return unless auth_config
          options = options.merge(auth_config).
            merge(configure_prefix_suffix).
            merge(configure_open_tweet_url)
        else
          # retain config when disabling
          options = configuration.merge(options)
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
      def run_capture_ready
        status = build_tweet(runner.message)
        file   = File.open(runner.main_image, 'rb')

        print "Tweeting ... "

        begin
          client = twitter_client.new(
            configuration[:token],
            configuration[:token_secret]
          )

          debug "--> Uploading media (#{file.size} bytes)"
          media_id = client.upload_media(file)
          debug "--> Posting status update (#{status.length} chars, media_id: #{media_id})"
          status_response = client.update_status(status, media_ids: [media_id])

          tweet_url = status_response['entities']['media'][0]['url']
          print "#{tweet_url}\n"
          open_url(tweet_url) if configuration[:open_tweet_url]
        rescue StandardError => e
          puts "ERROR: Tweeting FAILED! - #{e.message}"
        end
      end

      private

      def twitter_client
        Lolcommits::Twitter::Client
      end

      def build_tweet(commit_message)
        prefix = configuration[:prefix].to_s
        suffix = configuration[:suffix].to_s
        prefix = "#{configuration[:prefix]} " unless prefix.empty?
        suffix = " #{configuration[:suffix]}" unless suffix.empty?

        available_commit_msg_size = twitter_client::MAX_TWEET_CHARS - (prefix.length + suffix.length)
        if commit_message.length > available_commit_msg_size
          commit_message = "#{commit_message[0..(available_commit_msg_size - 3)]}..."
        end

        "#{prefix}#{commit_message}#{suffix}"
      end

      def ask_yes_or_no?(default: false)
        yes_or_no = parse_user_input(gets.strip)
        return default if yes_or_no.nil?
        !!(yes_or_no =~ /^y/i)
      end

      def configure_auth!
        if valid_configuration?
          print "\n* Reset Twitter Auth ? (y/N): "
          return configuration.select {|k,v| k.to_s =~ /^token/ } if !ask_yes_or_no?
        end

        puts ''
        puts '-----------------------------------'
        puts '    OK, lets setup Twitter Auth    '
        puts '-----------------------------------'

        request_token = twitter_client.oauth_consumer.get_request_token
        authorize_url = request_token.authorize_url

        open_url(authorize_url)
        print "\n* Grab a PIN from this url:\n\n"
        puts "   #{authorize_url}"

        print "\n* Type PIN, then press Enter: "
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
        puts '-----------------------------------'
        puts '  Thanks, Twitter Auth Succeeded!  '
        puts '-----------------------------------'

        {
          token: access_token.token,
          token_secret: access_token.secret
        }
      end

      def configure_prefix_suffix
        print "\n* Prefix all tweets with something? e.g. @user (default: nothing): "
        prefix = gets.strip
        print "\n* End all tweets with something? e.g. #hashtag (default: #{DEFAULT_SUFFIX}): "
        suffix = gets.strip

        config = {}
        config[:prefix] = prefix.empty? ? '' : prefix
        config[:suffix] = suffix.empty? ? DEFAULT_SUFFIX : suffix
        config
      end

      def configure_open_tweet_url
        print "\n* Automatically open Tweet URL after posting (y/N): "
        { open_tweet_url:  ask_yes_or_no? }
      end

      def open_url(url)
        Lolcommits::CLI::Launcher.open_url(url)
      end
    end
  end
end
