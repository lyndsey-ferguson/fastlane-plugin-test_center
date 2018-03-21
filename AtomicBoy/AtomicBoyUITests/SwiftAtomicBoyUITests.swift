//
//  SwiftAtomicBoyUITests.swift
//  AtomicBoyUITests
//
//

import XCTest

class SwiftAtomicBoyUITests: XCTestCase {
    
    func testExample() {
        let _ = TestObject(testcase: self)
        if (arc4random_uniform(6) < 3) {
            XCTAssertTrue(false)
        }
    }
    
}
