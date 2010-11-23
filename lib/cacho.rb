# encoding: UTF-8

require "json" unless defined?(JSON)
require "curb"
require "nest"

class Cacho
  VERSION = "0.0.1"

  def self.get(url, request_headers = {})
    _request(:get, url, request_headers)
  end

  def self.head(url, request_headers = {})
    _request(:head, url, request_headers)
  end

  def self.options(url, request_headers = {})
    _request(:options, url, request_headers)
  end

  def self._request(verb, url, request_headers = {})
    local = Local[verb, url]

    unless local.fresh?
      remote = Remote.request(verb, url, local.build_headers.merge(request_headers))

      local.set(remote) if remote
    end

    local.response
  end

  class Local
    attr :etag
    attr :last_modified
    attr :expire
    attr :response

    def initialize(key)
      @key = key
      @etag, @last_modified, @expire, @response = @key.hmget(:etag, :last_modified, :expire, :response)
      @response = JSON.parse(@response) if @response
    end

    def self.[](verb, url)
      new(Nest.new(verb)[url])
    end

    def expire_in(ttl)
      @expire = (Time.now + ttl).to_i
    end

    def build_headers
      {}.tap do |headers|
        headers["If-None-Match"] = etag if etag
        headers["If-Modified-Since"] = last_modified if last_modified
      end
    end

    def set(response)
      @response = response

      return unless cacheable?

      _, headers, _ = response

      if headers["Cache-Control"]
        ttl = headers["Cache-Control"][/max\-age=(\d+)/, 1].to_i
        expire_in(ttl)
      end

      @etag = headers["ETag"]
      @last_modified = headers["Last-Modified"]

      store
    end

    def fresh?
      expire && expire.to_i >= Time.now.to_i
    end

  protected

    def cacheable?
      status, headers, _ = response

      status == 200 && (headers["Cache-Control"] || headers["ETag"] || headers["Last-Modified"])
    end

    def store
      @key.hmset(
        :etag, etag,
        :last_modified, last_modified,
        :expire, expire,
        :response, response.to_json
      )
    end
  end

  class Remote
    def self.request(verb, url, request_headers)
      status = nil
      headers = {}
      body = ""

      curl = Curl::Easy.new(url)

      curl.headers = request_headers

      curl.on_header do |header|
        headers.store(*header.rstrip.split(": ", 2)) if header.include?(":")
        header.bytesize
      end

      curl.on_body do |string|
        body << string.force_encoding(Encoding::UTF_8)
        string.bytesize
      end

      curl.on_complete do |response|
        status = response.response_code
      end

      curl.head = verb == :head

      curl.http(verb.to_s.upcase)

      [status, headers, body] unless status == 304
    end

    def self.redis
      Redis.current
    end
  end
end
