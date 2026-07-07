Pod::Spec.new do |s|
  s.name             = 'BytesSDK'
  s.version          = '0.2.0'
  s.summary          = 'Bytes SDK for iOS — vertical-video experience.'
  s.description      = 'Media.net Bytes SDK. Provides a vertical-video (shorts-style) experience for iOS apps.'
  s.homepage         = 'https://github.com/media-net/bytes-packages'
  s.license          = { :type => 'Commercial' }
  s.author           = 'Media.net'

  s.platform              = :ios, '14.0'
  s.swift_version         = '5.9'
  s.source                = { :http => 'https://github.com/media-net/bytes-packages/releases/download/v0.2.0/BytesSDK-0.2.0.xcframework.zip' }
  s.vendored_frameworks   = 'BytesSDK.xcframework'
  s.module_name           = 'BytesSDK'
end
