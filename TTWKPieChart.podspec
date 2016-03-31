Pod::Spec.new do |s|
  s.name             = "TTWKPieChart"
  s.version          = "0.2.1"
  s.summary          = "Animated Apple Watch pie chart aka activity aka progress view."
  s.description      = <<-DESC
                        A component that simplifies creating of animated Apple Watch style pie charts
                        similar to the ones displayed by the Activity app.
                       DESC
  s.homepage         = "https://github.com/touchtribe/TTWKPieChart"
  s.screenshots      = 'https://raw.githubusercontent.com/TouchTribe/TTWKPieChart/master/Screenshot-AppleWatch.gif'
  s.license          = 'MIT'
  s.author           = { "TouchTribe B.V." => "info@touchtribe.nl" }
  s.source           = { :git => "https://github.com/touchtribe/TTWKPieChart.git", :tag => s.version.to_s }

  s.ios.deployment_target = '7.0'
  s.watchos.deployment_target = '1.0'
  
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
end
