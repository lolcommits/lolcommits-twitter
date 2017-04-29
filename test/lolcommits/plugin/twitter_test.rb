require 'test_helper'

describe Lolcommits::Plugin::Twitter do

  include Lolcommits::TestHelpers::GitRepo
  include Lolcommits::TestHelpers::FakeIO

  def plugin_name
    'twitter'
  end

  it 'should have a name' do
    ::Lolcommits::Plugin::Twitter.name.must_equal plugin_name
  end

  it 'should run on post capturing' do
    ::Lolcommits::Plugin::Twitter.runner_order.must_equal [:captureready]
  end

  describe 'with a runner' do
    def runner
      # a simple lolcommits runner with an empty configuration Hash
      @runner ||= Lolcommits::Runner.new(
        config: OpenStruct.new(read_configuration: {})
      )
    end

    def plugin
      @plugin ||= Lolcommits::Plugin::Twitter.new(runner)
    end

    def valid_enabled_config
      @config ||= OpenStruct.new(
        read_configuration: {
          plugin.class.name => { 'enabled' => true }
        }
      )
    end

    describe 'initalizing' do
      it 'should assign runner and an enabled option' do
        plugin.runner.must_equal runner
        plugin.options.must_equal ['enabled']
      end
    end

    describe '#enabled?' do
      it 'should be true by default' do
        plugin.enabled?.must_equal true
      end

      it 'should true when configured' do
        plugin.runner.config = valid_enabled_config
        plugin.enabled?.must_equal true
      end
    end

    describe 'configuration' do
      it 'should not be configured by default' do
        plugin.configured?.must_equal false
      end

      it 'should allow plugin options to be configured' do
        # enabled
        inputs = ['true']
        inputs += %w()

        configured_plugin_options = {}
        output = fake_io_capture(inputs: inputs) do
          configured_plugin_options = plugin.configure_options!
        end

        configured_plugin_options.must_equal({
          "enabled" => true
        })
      end

      it 'should indicate when configured' do
        plugin.runner.config = valid_enabled_config
        plugin.configured?.must_equal true
      end

      describe '#valid_configuration?' do
        it 'should be trye even if config is not set' do
          plugin.valid_configuration?.must_equal(true)
        end

        it 'should be true for a valid configuration' do
          plugin.runner.config = valid_enabled_config
          plugin.valid_configuration?.must_equal true
        end
      end
    end
  end
end
