require_relative "../lib/cacho"

client = Cacho.new

puts client.request(:get, "https://news.ycombinator.com")
