#
# Be sure to run `pod lib lint MSServerSentEvents.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "MSServerSentEvents"
  s.version          = "0.1.0"
  s.summary          = "A native Objective-C implementation of Server-Sent Events"
  s.description      = <<-DESC
                       Improve your iOS app’s user experience and utility with our open-source, standards-based real-time data library
                       DESC
  s.homepage         = "https://github.com/makeandship/MSServerSentEvents"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Simon Heys" => "simon@makeandship.co.uk" }
  s.source           = { :git => "https://github.com/makeandship/MSServerSentEvents.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/makeandship'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'MSServerSentEvents' => ['Pod/Assets/*.png']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'libextobjc/EXTScope', '~> 0.4'
end
