require_relative "lib/cacho"

Gem::Specification.new do |s|
  s.name              = "cacho"
  s.version           = Cacho::VERSION
  s.summary           = "A careless caching client optimized for scraping."
  s.description       = "A careless caching client optimized for scraping."
  s.authors           = ["Damian Janowski", "Michel Martens"]
  s.email             = ["djanowski@dimaion.com", "michel@soveran.com"]
  s.homepage          = "https://github.com/djanowski/cacho"

  s.files = `git ls-files`.lines.to_a.map(&:chomp)

  s.add_dependency "net-http-persistent"
end
