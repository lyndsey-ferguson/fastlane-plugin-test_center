//
//  SwiftAtomicBoyUITests.swift
//  AtomicBoyUITests
//
//

import Quick

class SwiftAtomicBoyUITests: QuickSpec {

  override func spec() {
    it("sometime succeeds") {
      let _ = TestObject(testcase: self)
      if (arc4random_uniform(6) < 3) {
          XCTAssertTrue(false)
      }
    }
  }
}
