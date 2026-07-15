Pod::Spec.new do |s|
  s.name         = "LingvanexAPI"
  s.version      = "2.0.0"
  s.summary      = "Swift client for the Lingvanex Translation API."
  s.description  = <<-DESC
                   A Swift client for the Lingvanex Translation API: text
                   translation and the list of supported languages, with
                   async/await, typed errors and cancellation.
                   DESC
  s.homepage     = "https://github.com/artdima/LingvanexAPI"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Medyannik Dmitriy" => "mail@artdima.ru" }

  s.ios.deployment_target     = "15.0"
  s.osx.deployment_target     = "12.0"
  s.tvos.deployment_target    = "15.0"
  s.watchos.deployment_target = "8.0"

  s.swift_version = "5.9"
  s.source        = { :git => "https://github.com/artdima/LingvanexAPI.git", :tag => s.version.to_s }
  s.source_files  = "Sources/LingvanexAPI/**/*.swift"
  s.requires_arc  = true
end
