# frozen_string_literal: true

require 'test_helper'

describe Lolcommits::Plugin::Twitter do

  include Lolcommits::TestHelpers::FakeIO

  describe 'with a runner' do
    def runner
      @_runner ||= Lolcommits::Runner.new
    end

    def valid_enabled_config
      {
        enabled: true,
        token: 'abc-xyz',
        token_secret: '123XYZ'
      }
    end

    def plugin
      @_plugin ||= Lolcommits::Plugin::Twitter.new(runner: runner)
    end

    def twitter_client
      Lolcommits::Twitter::Client
    end

    describe '#enabled?' do
      it 'returns false by default' do
        _(plugin.enabled?).must_equal false
      end

      it 'returns true when configured' do
        plugin.configuration = valid_enabled_config
        _(plugin.enabled?).must_equal true
      end
    end

    describe 'configuration' do
      it 'does not have a valid config by default' do
        _(plugin.valid_configuration?).must_equal false
      end

      it 'indicates when configured correctly' do
        plugin.configuration = valid_enabled_config
        _(plugin.valid_configuration?).must_equal true
      end

      it 'allows plugin options to be configured' do
        stub_request(:post, "#{Lolcommits::Twitter::Client::API_ENDPOINT}/oauth/request_token").
          to_return(status: 200, body: "oauth_token=mytoken&oauth_token_secret=mytokensercet&oauth_callback_confirmed=true")

        stub_request(:post, "#{Lolcommits::Twitter::Client::API_ENDPOINT}/oauth/access_token").
          to_return(status: 200, body: "oauth_token=oauthtoken&oauth_token_secret=oauthtokensecret&user_id=6253282&screen_name=twitterapi")

        # enabled, AUTH PIN, prefix, suffix, Yes/No auto open
        inputs = %w(true 123456 LOL-prefix LOL-suffix Y)

        configured_plugin_options = {}
        fake_io_capture(inputs: inputs) do
          configured_plugin_options = plugin.configure_options!
        end

        _(configured_plugin_options).must_equal({
          enabled: true,
          token: 'oauthtoken',
          token_secret: 'oauthtokensecret',
          prefix: 'LOL-prefix',
          suffix: 'LOL-suffix',
          open_tweet_url: true
        })
      end
    end
  end
end
