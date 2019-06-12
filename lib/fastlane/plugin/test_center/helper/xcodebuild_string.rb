module TestCenter
  module Helper
    MUST_SHELLESCAPE_TESTIDENTIFIER = Gem::Version.new(Fastlane::VERSION) < Gem::Version.new('2.114.0')
  end
end

class String
  def testsuite_swift?
    self.include?('.')
  end

  def testsuite
    if self.testsuite_swift?
      self.split('.')[1]
    else
      self
    end
  end

  def shellsafe_testidentifier
    TestCenter::Helper::MUST_SHELLESCAPE_TESTIDENTIFIER ? self.shellescape : self
  end
  
  def strip_testcase
    split('/').first(2).join('/')
  end
end
