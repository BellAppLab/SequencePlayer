Pod::Spec.new do |spec|
  spec.name         = 'SequencePlayer'
  spec.version      = '0.1.0'
  spec.license      = { :type => 'MIT' }
  spec.homepage     = 'https://github.com/BellAppLab/SequencePlayer'
  spec.authors      = { 'Bell App Lab' => 'apps@bellapplab.com' }
  spec.summary      = 'Play a series of media files in sequence with no lags on iOS.'
  spec.source       = { :git => 'https://github.com/BellAppLab/SequencePlayer.git', :tag => '0.1.0' }
  spec.source_files = 'Source/SequencePlayer.swift'
  spec.framework    = 'AVFoundation'
end