Pod::Spec.new do |spec|

  spec.name         = "PhotographyKit"
  spec.version      = "0.22"
  spec.license      = "MIT"
  spec.summary      = "A swift library for quickly integrating a built in camera session into your app."
  spec.homepage     = "https://github.com/appoly/PhotographyKit"
  spec.authors = "James Wolfe"
  spec.source = { :git => 'https://github.com/appoly/PhotographyKit.git', :tag => spec.version }

  spec.ios.deployment_target = "11.4"
  spec.framework = "UIKit"
  spec.framework = "AVFoundation"
  spec.framework = "CoreImage"

  spec.swift_versions = ["5.0", "5.1"]
  
  spec.source_files = "Sources/PhotographyKit/*.swift"
  

end
