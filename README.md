# Lolcommits Twitter




[![Gem](https://img.shields.io/gem/v/lolcommits-twitter.svg?style=flat)](http://rubygems.org/gems/lolcommits-twitter)
[![Travis](https://img.shields.io/travis/com/lolcommits/lolcommits-twitter/master.svg?style=flat)](https://travis-ci.com/lolcommits/lolcommits-twitter)
[![Depfu](https://img.shields.io/depfu/lolcommits/lolcommits-twitter.svg?style=flat)](https://depfu.com/github/lolcommits/lolcommits-twitter)
[![Maintainability](https://api.codeclimate.com/v1/badges/e6c4f22b17de9df4e3da/maintainability)](https://codeclimate.com/github/lolcommits/lolcommits-twitter/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/e6c4f22b17de9df4e3da/test_coverage)](https://codeclimate.com/github/lolcommits/lolcommits-twitter/test_coverage)

[lolcommits](https://lolcommits.github.io/) takes a snapshot with your webcam
every time you git commit code, and archives a lolcat style image with it. Git
blame has never been so much fun!

This plugin automatically posts your Lolcommit to Twitter. The tweet features
your commit message (shortened, with some optional surrounding text) and the
captured image. See the [#lolcommits](https://twitter.com/hashtag/lolcommits)
hash tag for some examples in the wild. You can also configure the plugin to
auto-open the tweet in your default browser.

## Requirements

* Ruby >= 2.3
* A webcam
* [ImageMagick](http://www.imagemagick.org)
* [ffmpeg](https://www.ffmpeg.org) (optional) for animated gif capturing

## Installation

After installing the lolcommits gem, install this plugin with:

    $ gem install lolcommits-twitter

The configure the plugin to enable it and auth with Twitter

    $ lolcommits --config -p twitter
    # set enabled to `true` (then set your own options or choose the defaults)

*NOTE*: if you enable this plugin on another repository you may want to copy the
credentials from `~/.lolcommits/{your-repo}/config.yml` (so Twitter does not
de-authorize the connection).

### Configuration

The following options are available:

* prefix
* suffix (default: #lolcommits)
* auto-open tweet url?

You can always reconfigure the plugin later, to change these options without
having to re-authenicate with Twitter.

To disable - set `enabled: false` and revoke plugin access to your twitter
account [here](https://twitter.com/settings/applications).



## Development

Check out this repo and run `bin/setup`, to install all dependencies and
generate docs. Run `bundle exec rake` to run all tests and generate a coverage
report.

You can also run `bin/console` for an interactive prompt that will allow you to
experiment with the gem code.

## Tests

MiniTest is used for testing. Run the test suite with:

    $ rake test

## Docs

Generate docs for this gem with:

    $ rake rdoc

## Troubles?

If you think something is broken or missing, please raise a new
[issue](https://github.com/lolcommits/lolcommits-twitter/issues). Take
a moment to check it hasn't been raised in the past (and possibly closed).

## Contributing

Bug [reports](https://github.com/lolcommits/lolcommits-twitter/issues) and [pull
requests](https://github.com/lolcommits/lolcommits-twitter/pulls) are welcome on
GitHub.

When submitting pull requests, remember to add tests covering any new behaviour,
and ensure all tests are passing on [Travis
CI](https://travis-ci.com/lolcommits/lolcommits-twitter). Read the
[contributing
guidelines](https://github.com/lolcommits/lolcommits-twitter/blob/master/CONTRIBUTING.md)
for more details.

This project is intended to be a safe, welcoming space for collaboration, and
contributors are expected to adhere to the [Contributor
Covenant](http://contributor-covenant.org) code of conduct. See
[here](https://github.com/lolcommits/lolcommits-twitter/blob/master/CODE_OF_CONDUCT.md)
for more details.

## TODO

- [ ] Refactor Client to include Request/Response classes (see twitter gem approach)
- [ ] Tests for Client lib classes
- [ ] Tests for Plugin class (port tests from lolcommits)
- [ ] Test running `capture_ready` method (stub with webmock?)
- [ ] Correctly stub out launcher, or have it do nothing in tests
- [ ] Update README
- [ ] Check gem dependencies are correct

## License

The gem is available as open source under the terms of
[LGPL-3](https://opensource.org/licenses/LGPL-3.0).

## Links

* [Travis CI](https://travis-ci.com/lolcommits/lolcommits-twitter)
* [Test Coverage](https://codeclimate.com/github/lolcommits/lolcommits-twitter/test_coverage)
* [Code Climate](https://codeclimate.com/github/lolcommits/lolcommits-twitter)
* [RDoc](http://rdoc.info/projects/lolcommits/lolcommits-twitter)
* [Issues](http://github.com/lolcommits/lolcommits-twitter/issues)
* [Report a bug](http://github.com/lolcommits/lolcommits-twitter/issues/new)
* [Gem](http://rubygems.org/gems/lolcommits-twitter)
* [GitHub](https://github.com/lolcommits/lolcommits-twitter)
