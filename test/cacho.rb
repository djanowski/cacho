# encoding: UTF-8

require "cutest"
require "socket"
require "mock_server"

require File.expand_path("../lib/cacho", File.dirname(__FILE__))

include MockServer::Methods

mock_server do
  %w(GET OPTIONS).each do |method|
    route method, "/cacheable" do
      response.headers["Cache-Control"] = "public, max-age=2"
      response.headers["Content-Type"] = "text/plain"
      Time.now.httpdate
    end
  end

  get "/non-cacheable" do
    response.headers["Content-Type"] = "text/plain"
    Time.now.httpdate
  end

  get "/etag" do
    if request.env["HTTP_IF_MODIFIED_SINCE"]
      halt 304
    else
      time = Time.now

      response.headers["ETag"] = time.hash.to_s
      response.headers["Last-Modified"] = time.httpdate
      response.headers["Content-Type"] = "text/plain"

      time.httpdate
    end
  end

  get "/changing-etag" do
    if request.env["HTTP_IF_MODIFIED_SINCE"]
      time = Time.parse(request.env["HTTP_IF_MODIFIED_SINCE"]) + 1
    else
      time = Time.now

      response.headers["ETag"] = time.hash.to_s
      response.headers["Last-Modified"] = time.httpdate
      response.headers["Content-Type"] = "text/plain"
    end

    time.httpdate
  end

  get "/utf" do
    "Aló"
  end

  def route_missing
    request.env.map do |name, value|
      "#{name}: #{value}"
    end.join("\n")
  end
end

prepare do
  Redis.current.flushdb
end

test "handles GET" do
  _, _, body = Cacho.get("http://localhost:4000")

  assert body["REQUEST_METHOD: GET"]
end

test "handles OPTIONS" do
  _, _, body = Cacho.options("http://localhost:4000")

  assert body["REQUEST_METHOD: OPTIONS"]
end

test "handles HEAD" do
  status, headers, body = Cacho.head("http://localhost:4000")

  assert status == 200
  assert headers["Content-Type"]
  assert body.empty?
end

test "caches cacheable responses" do
  status, headers, body = Cacho.get("http://localhost:4000/cacheable")

  assert_equal status, 200
  assert_equal headers["Content-Type"], "text/plain"

  t1 = body

  sleep 1

  status, headers, body = Cacho.get("http://localhost:4000/cacheable")

  assert_equal t1, body

  sleep 2

  status, headers, body = Cacho.get("http://localhost:4000/cacheable")

  assert body > t1
end

test "varies cache by HTTP method" do
  status1, _, body1 = Cacho.get("http://localhost:4000/cacheable")
  sleep 1
  status2, _, body2 = Cacho.options("http://localhost:4000/cacheable")

  assert status1 == 200
  assert status2 == 200

  assert body2 > body1
end

test "does not cache non-cacheable responses" do
  _, _, t1 = Cacho.get("http://localhost:4000/non-cacheable")
  sleep 1
  _, _, t2 = Cacho.get("http://localhost:4000/non-cacheable")

  assert t2 > t1
end

test "performs conditional GETs" do
  _, _, t1 = Cacho.get("http://localhost:4000/etag")
  sleep 1
  _, _, t2 = Cacho.get("http://localhost:4000/etag")

  assert_equal t1, t2

  _, _, t1 = Cacho.get("http://localhost:4000/changing-etag")
  _, _, t2 = Cacho.get("http://localhost:4000/changing-etag")

  assert t2 > t1
end

test "allows to pass custom HTTP headers" do
  _, _, body = Cacho.get("http://localhost:4000", "Accept" => "text/plain")

  assert body["HTTP_ACCEPT: text/plain"]
end

test "accepts UTF-encoded bodies" do
  _, _, body = Cacho.get("http://localhost:4000/utf")

  assert body.include?("Aló")
  assert body.encoding == Encoding::UTF_8
end
