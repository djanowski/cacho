require "cutest"
require "socket"
require "mock_server"

require File.expand_path("../lib/cacho", File.dirname(__FILE__))

include MockServer::Methods

mock_server do
  get "/cacheable" do
    response.headers["Cache-Control"] = "public, max-age=1"
    response.headers["Content-Type"] = "text/plain"
    Time.now.httpdate
  end

  get "/non-cacheable" do
    response.headers["Content-Type"] = "text/plain"
    Time.now.httpdate
  end

  get "/etag" do
    if request.env["HTTP_IF_MODIFIED_SINCE"]
      halt 301
    else
      time = Time.now

      response.headers["Etag"] = time.hash.to_s
      response.headers["Last-Modified"] = time.httpdate
      response.headers["Content-Type"] = "text/plain"

      time.httpdate
    end
  end
end

prepare do
  Redis.current.flushdb
end

test "caches cacheable responses" do
  status, headers, body = Cacho.get("http://localhost:4000/cacheable")

  assert_equal status, 200
  assert_equal headers["Content-Type"], "text/plain"

  t1 = body

  status, headers, body = Cacho.get("http://localhost:4000/cacheable")

  assert_equal t1, body

  sleep 2

  status, headers, body = Cacho.get("http://localhost:4000/cacheable")

  assert body > t1
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
end
