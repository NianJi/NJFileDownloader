Pod::Spec.new do |s|
  s.name         = "NJFileDownloader"
  s.version      = "0.0.7"
  s.summary      = "download file from server"

  s.description  = <<-DESC
                    a download file plugin use NSURLSession.
                   DESC
  
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'

  s.homepage     = "https://github.com/NianJi/NJFileDownloader"
  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author       = { "念纪" => "fengnianji@gmail.com" }
  s.source       = { :git => "https://github.com/NianJi/NJFileDownloader.git", :tag => "0.0.7" }

  s.source_files  = "NJFileDownloader/*.{h,m}"

  s.requires_arc = true

  s.frameworks = 'Foundation'

end
