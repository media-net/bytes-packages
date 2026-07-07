Pod::Spec.new do |s|
  s.name             = 'BytesAdSourceMediaNet'
  s.version          = '1.0.0'
  s.summary          = 'Media.net ad source for the Bytes SDK.'
  s.description      = 'Thin glue that lets the Bytes SDK render Media.net demand. Links the Media.net Ad SDK from media-net/ios-packages.'
  s.homepage         = 'https://github.com/media-net/bytes-packages'
  s.license          = { :type => 'Commercial' }
  s.author           = 'Media.net'

  s.platform              = :ios, '14.0'
  s.swift_version         = '5.9'
  s.source                = { :git => 'https://github.com/media-net/bytes-packages.git', :tag => 'v1.0.0' }
  s.source_files          = 'Sources/BytesAdSourceMediaNet/*.swift'

  s.dependency 'BytesSDK', '1.0.0'
  s.dependency 'MediaNetAdSDK', '>= 0.4.6'
  s.dependency 'MediaNetRendererAdSDK'
end
