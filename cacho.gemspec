Gem::Specification.new do |s|
  s.name              = "cacho"
  s.version           = "0.0.1"
  s.summary           = "Object Oriented Keys for Redis."
  s.description       = "It is a design pattern in key-value databases to use the key to simulate structure, and Nest can take care of that."
  s.authors           = ["Damian Janowski", "Michel Martens"]
  s.email             = ["damian@dimaion.com", "michel@soveran.com"]
  s.homepage          = "http://github.com/djanowski/cacho"
  s.files = ["LICENSE", "Rakefile", "lib/cacho.rb", "cacho.gemspec", "test/cacho.rb"]
  s.add_dependency "curb", "~> 0.7"
  s.add_dependency "mock-server", "~> 0.1"
end
