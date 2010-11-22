require "curb"
require "redis"
require "json"

class Cacho
  VERSION = "0.0.1"

  def self.get(url, request_headers = {})
    response = Local.get(url)

    if response.nil?
      response = Remote.get(url, Local.validation_for(url).merge(request_headers))
      Local.set(url, response)
    end

    response
  end

  class Local
    def self.get(url)
      expire, json = redis.hmget(url, :expire, :response)

      if json && (expire.nil? || Time.utc(expire) <= Time.now)
        JSON.parse(json)
      end
    end

    def self.set(url, response)
      return unless cacheable?(response)

      _, headers, _ = response

      fields = {}

      if headers["Cache-Control"]
        ttl = headers["Cache-Control"][/max\-age=(\d+)/, 1].to_i

        fields[:expire] = (Time.now + ttl).to_i
      end

      fields[:response] = response.to_json

      fields[:etag] = headers["Etag"]
      fields[:last_modified] = headers["Last-Modified"]

      redis.hmset(url, *fields.to_a.flatten)
    end

    def self.validation_for(url)
      etag, last_modified = redis.hmget(url, :etag, :last_modified)

      {}.tap do |headers|
        headers["If-None-Match"] = etag if etag
        headers["If-Modified-Since"] = last_modified if last_modified
      end
    end

    def self.cacheable?(response)
      status, headers, _ = response

      status == 200 && (headers["Cache-Control"] || headers["Etag"] || headers["Last-Modified"])
    end

    def self.redis
      Redis.current
    end
  end

  class Remote
    def self.get(url, request_headers)
      status = nil
      headers = {}
      body = ""

      Curl::Easy.http_get(url) do |curl|
        curl.headers = request_headers

        curl.on_header do |header|
          headers.store(*header.rstrip.split(": ", 2)) if header.include?(":")
          header.bytesize
        end

        curl.on_body do |string|
          body << string
          string.bytesize
        end

        curl.on_complete do |response|
          status = response.response_code
        end
      end

      if status == 301
        Local.get(url)
      else
        [status, headers, body]
      end
    end

    def self.redis
      Redis.current
    end
  end
end
