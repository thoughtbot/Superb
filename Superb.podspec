Pod::Spec.new do |s|
  s.name = "Superb"
  s.version = %x(git describe --tags --abbrev=0).chomp
  s.summary = "Pluggable HTTP authentication for Swift."
  s.homepage = "https://github.com/thoughtbot/Superb"
  s.license = { type: "MIT", file: "LICENSE" }
  s.author = {
    "Adam Sharp" => "adam@thoughtbot.com",
    "Nick Charlton" => "nc@thoughtbot.com",
    "thoughtbot" => nil,
  }
  s.social_media_url = "https://twitter.com/thoughtbot"
  s.platform = :ios, "8.0"
  s.source = { git: "https://github.com/thoughtbot/Superb.git", tag: "#{s.version}" }
  s.source_files = "Sources/#{s.name}/**/*.{swift,h}"
  s.module_map = "Sources/#{s.name}/module.modulemap"
  s.public_header_files = "Sources/#{s.name}/#{s.name}.h"
  s.dependency "Result", "~> 3.1"
end
