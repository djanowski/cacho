Cacho
=====

A careless caching client optimized for scraping.

Description
-----------

Cacho is an HTTP client for scraping. It will do most of the things you want
when scraping:

* Follow redirects.
* Set the `User-Agent` to a browser-like string.
* Accept and process gzip encoding.
* Detect when it's been rate limited and wait.
* Retry on silly network errors.
* Use persistent HTTP connections.

Most importantly, Cacho will store responses on disk so that multiple runs of
your script will not hit the endpoints you are scraping. This prevents being
rate limited and also makes your script faster every time.

Usage
-----

    require "cacho"

    client = Cacho.new

    res = client.request(:get, "https://news.ycombinator.com")

Installation
------------

    $ gem install cacho

License
-------

See the `UNLICENSE`.
