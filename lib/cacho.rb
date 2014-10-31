require "net/http/persistent"
require "uri"
require "zlib"
require "json"
require "stringio"
require "csv"
require "fileutils"

class Cacho
  VERSION = "0.1.0"

  attr_accessor :hasher

  def initialize(*args)
    @client = Client.new(*args)
    @db = DB.new("~/.cacho/cache")
    @hasher = -> *args { args }
  end

  def request(verb, *args)
    if verb == :get
      uri = @client.uri(*args)

      @db.get(verb, uri) do
        @client.request(verb, *args)
      end
    else
      @client.request(verb, *args)
    end
  end
end

class Cacho::Client
  Error = Class.new(StandardError)
  NotFound = Class.new(Error)

  def initialize(callbacks = {})
    @http = Net::HTTP::Persistent.new
    @callbacks = callbacks
    @callbacks[:configure_http].(@http) if @callbacks[:configure_http]
  end

  def uri(url, options = {})
    query = options.fetch(:query, {}).dup

    @callbacks[:process_query].(query) if @callbacks[:process_query]

    uri = URI(url)

    uri.query = URI.encode_www_form(query) if query.size > 0

    uri
  end

  def request(verb, url, options = {})
    uri = self.uri(url, options)

    loop do
      request = Net::HTTP.const_get(verb.capitalize).new(uri.request_uri)

      @callbacks[:before_request].(request) if @callbacks[:before_request]

      if options.include?(:headers)
        options[:headers].each do |key, value|
          request[key] = value
        end
      end

      request["Accept-Encoding"] = "gzip"

      if verb == :post
        post_data = options.fetch(:data)

        case options[:content_type]
        when :json
          request["Content-Type"] = "application/json; charset=utf-8"
          request.body = post_data.to_json
        else
          request.body = URI.encode_www_form(post_data)
        end
      end

      if options[:content_encoding] == :deflate
        request["Content-Encoding"] = "deflate"

        request.body = Zlib::Deflate.deflate(request.body)
      end

      $stderr.puts("-> #{verb.upcase} #{uri}")

      if verb_idempotent?(verb)
        res = protect { @http.request(uri, request) }
      else
        res = @http.request(uri, request)
      end

      body = res.body

      if res["Content-Encoding"] == "gzip"
        body = Zlib::GzipReader.new(StringIO.new(body)).read
      end

      if res["Content-Type"] && res["Content-Type"].start_with?("application/json")
        parsed = JSON.parse(body)
      else
        parsed = body
      end

      if @callbacks[:rate_limit_detector]
        if seconds = @callbacks[:rate_limit_detector].(res, body, parsed)
          $stderr.puts("Rate limited for #{seconds} seconds.")
          sleep(seconds)
          next
        end
      end

      case res.code
      when "200"
        return parsed
      when "303" , "302" , "301"
        if res["Location"].to_s.index(/^https?:\/\//)
          redirect_url = URI.escape(res["Location"])
        else
          redirect_url = @base_url, res["Location"]
        end
        $stderr.write(" redirected to #{redirect_url}\n") 
        uri = URI.join(redirect_url)
      when "404"
        return nil
      else
        raise "Got #{res.code}: #{body.inspect}"
      end
    end
  end

  def verb_idempotent?(verb)
    verb == :get || verb == :head || verb == :options
  end

  def protect(options = {})
    throttle = options.fetch(:throttle, 1)
    maximum_retries = options.fetch(:retries, nil)
    retries = 0

    begin
      result = yield

      retries = 0

      return result
    rescue SocketError, \
           EOFError, \
           Errno::ECONNREFUSED, \
           Errno::ECONNRESET, \
           Errno::EHOSTUNREACH, \
           Errno::ENETUNREACH, \
           Net::HTTP::Persistent::Error, \
           Errno::ETIMEDOUT

      retries += 1

      $stderr.puts("-> #{$!.class}: #{$!.message}")

      sleep([retries ** 2 * throttle, 300].min)

      retry if maximum_retries.nil? || retries < maximum_retries
    end
  end
end

class Cacho::DB
  attr :path

  def initialize(path)
    @path = File.expand_path(path)

    FileUtils.mkdir_p(@path)
  end

  def get(verb, uri)
    parts = [
      "#{uri.host}-#{uri.port}",
      verb.to_s,
      Digest::MD5.hexdigest(uri.to_s)
    ]

    doc_path = File.join(@path, *parts)

    FileUtils.mkdir_p(File.dirname(doc_path)) if doc_path.start_with?(@path)

    if File.exist?(doc_path)
      str = File.read(doc_path)

      return Marshal.load(str)
    else
      value = yield

      File.write(doc_path, Marshal.dump(value))

      return value
    end
  end
end
