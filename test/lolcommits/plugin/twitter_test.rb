require 'test_helper'

describe Lolcommits::Plugin::Twitter do

  include Lolcommits::TestHelpers::FakeIO

  it 'should run on post capturing' do
    ::Lolcommits::Plugin::Twitter.runner_order.must_equal [:capture_ready]
  end

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
      it 'should be false by default' do
        plugin.enabled?.must_equal false
      end

      it 'should true when configured' do
        plugin.configuration = valid_enabled_config
        plugin.enabled?.must_equal true
      end
    end

    describe 'configuration' do
      it 'should not have a valid config by default' do
        plugin.valid_configuration?.must_equal false
      end

      it 'should indicate when configured correctly' do
        plugin.configuration = valid_enabled_config
        plugin.valid_configuration?.must_equal true
      end

      it 'should allow plugin options to be configured' do
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

        configured_plugin_options.must_equal({
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
