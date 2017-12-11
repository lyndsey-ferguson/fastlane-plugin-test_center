
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
end
