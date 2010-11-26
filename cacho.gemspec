Gem::Specification.new do |s|
  s.name              = "cacho"
  s.version           = "0.0.3"
  s.summary           = "Cache aware, Redis based HTTP client."
  s.description       = "HTTP client that understands cache responses and stores results in Redis."
  s.authors           = ["Damian Janowski", "Michel Martens"]
  s.email             = ["djanowski@dimaion.com", "michel@soveran.com"]
  s.homepage          = "http://github.com/djanowski/cacho"

  s.files = ["LICENSE", "Rakefile", "lib/cacho.rb", "cacho.gemspec", "test/cacho.rb"]

  s.add_dependency "nest", "~> 1.0"
  s.add_dependency "curb", "~> 0.7"
end
