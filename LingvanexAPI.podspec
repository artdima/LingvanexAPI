Pod::Spec.new do |s|
s.name         = "LingvanexAPI"
s.version      = "0.0.1"
s.summary      = "LingvanexAPI"
s.description  = "A framework to use LingvaNex Translation API in Swift."
s.homepage     = "https://github.com/artdima/LingvanexAPI"
s.license      = { :type => "MIT" }
s.author       = { "Medyannik Dmitriy" => "mail@artdima.ru" }
s.platform     = :ios, "10.0"
s.swift_version = '4.2'
s.source       = { :git => "https://github.com/artdima/LingvanexAPI.git", :tag => s.version.to_s }
s.source_files = "Classes", "LingvanexAPI/Sources/**/*.{swift}"
s.requires_arc = true
end
