Pod::Spec.new do |s|
  s.name = 'NitroModules'
  s.version = '0.0.0'
  s.summary = 'Fixture for the podspec public header reader'
  s.source_files = 'ios/**/*.{h,m,mm,swift}', 'cpp/**/*.{hpp,cpp}'
  s.public_header_files = [
    "cpp/core/AnyMap.hpp",
    "cpp/core/Null.hpp"
  ]
  s.private_header_files = [
    "cpp/internal/Hidden.hpp"
  ]
end
