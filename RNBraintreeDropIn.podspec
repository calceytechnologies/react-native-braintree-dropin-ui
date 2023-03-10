Pod::Spec.new do |s|
  s.name         = "RNBraintreeDropIn"
  s.version      = "1.0.0"
  s.summary      = "RNBraintreeDropIn"
  s.description  = <<-DESC
                  RNBraintreeDropIn
                   DESC
  s.homepage     = "https://github.com/bamlab/react-native-braintree-payments-drop-in"
  s.license      = "MIT"
  # s.license      = { :type => "MIT", :file => "../LICENSE" }
  s.author             = { "author" => "lagrange.louis@gmail.com" }
  s.platform     = :ios, "9.0"
  s.source       = { :git => "https://github.com/BradyShober/react-native-braintree-dropin-ui.git", :tag => "master", :modular_headers => true }
  s.source_files  = "*.{h,m,swift}"
  s.requires_arc = true
  s.dependency    'React'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.dependency    'Braintree', '4.34.0'
  s.dependency    'BraintreeDropIn'
  s.dependency    'Braintree/DataCollector'
  s.dependency    'Braintree/Apple-Pay'
  s.dependency    'Braintree/Venmo'
  s.dependency    'PayCardsRecognizer', '1.1.7'
end
