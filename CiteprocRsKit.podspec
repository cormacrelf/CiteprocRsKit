Pod::Spec.new do |s|
    s.name             = 'CiteprocRsKit'
    s.version          = '0.0.1'
    s.summary          = 'citeproc-rs bindings for Swift'

    s.description      = <<-DESC
    citeproc-rs bindings for Swift
                         DESC

    s.homepage         = 'https://github.com/zotero/citeproc-rs'
    # s.license          = { :type => '', :file => 'LICENSE' }
    s.author           = { 
      'Cormac Relf' => 'cormac@cormacrelf.net',
    }
    s.source           = { :git => 'https://github.com/zotero/citeproc-rs', :tag => s.version.to_s }

    s.source_files = 'bindings/swift/CiteprocRsKit/**/*.{swift,h,a}'
    s.swift_version = '5.1'
    s.ios.deployment_target = '12.0'
    s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
    s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
    # s.dependency 'dependency-name', '= 0.0.0'
    s.ios.vendored_libraries = 'lib/libciteproc_rs.a'
    s.preserve_paths = ['Scripts', 'rust','docs','Cargo.*','CiteprocRsKit/Stencil']
    # s.prepare_command = <<-CMD
    # CMD

    s.script_phase = {
      :name => 'Build libciteproc_rs',
      :script => 'sh ${PODS_TARGET_SRCROOT}/Scripts/build_libciteproc_rs.sh',
      :execution_position => :before_compile
   }
   s.test_spec 'Tests' do | test_spec |
      test_spec.source_files = 'CiteprocRsKitTests/**/*.{swift}'
      test_spec.ios.resources = 'CiteprocRsKitTests/**/*.{db,params}'
      test_spec.script_phase = {
         :name => 'Build libciteproc_rs',
         :script => '${PODS_TARGET_SRCROOT}/Scripts/build_libciteproc_rs_xcode.sh --testing',
         :execution_position => :before_compile
      }
      # test_spec.dependency 'dependency-name', '= version'
  end
end
