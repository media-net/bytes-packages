Pod::Spec.new do |s|
  s.name             = 'BytesAdSourceMediaNet'
  s.version          = '1.0.2'
  s.summary          = 'Media.net ad source for the Bytes SDK.'
  s.description      = 'Thin glue that lets the Bytes SDK render Media.net demand. Links the Media.net Ad SDK and the Media.net renderer.'
  s.homepage         = 'https://github.com/media-net/bytes-packages'
  s.license          = { :type => 'Commercial' }
  s.author           = 'Media.net'

  s.platform              = :ios, '15.0'
  s.swift_version         = '5.9'
  s.source                = { :git => 'https://github.com/media-net/bytes-packages.git', :tag => 'v1.0.2' }
  s.source_files          = 'Sources/BytesAdSourceMediaNet/*.swift'
  s.static_framework      = true

  s.dependency 'BytesSDK', '1.0.2'
  # Same ranges as the SPM manifest's from: pins (>= X.Y.Z, < next major).
  s.dependency 'MediaNetAdSDK', '>= 1.0.2', '< 2.0'
  s.dependency 'MediaNetRendererAdSDK', '>= 1.0.4', '< 2.0'
end
