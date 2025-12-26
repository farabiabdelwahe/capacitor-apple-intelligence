Pod::Spec.new do |s|
  s.name = 'CapacitorAppleIntelligence'
  s.version = '1.0.0'
  s.summary = 'Capacitor plugin for Apple Intelligence with schema-constrained JSON generation'
  s.license = 'MIT'
  s.homepage = 'https://github.com/anthropic-labs/capacitor-apple-intelligence'
  s.author = 'Anthropic Labs'
  s.source = { :git => 'https://github.com/anthropic-labs/capacitor-apple-intelligence.git', :tag => s.version.to_s }
  s.source_files = 'ios/Sources/AppleIntelligencePlugin/**/*.{swift,h,m,c,cc,mm,cpp}'
  s.ios.deployment_target = '14.0'
  s.dependency 'Capacitor'
  s.swift_version = '5.9'
end
