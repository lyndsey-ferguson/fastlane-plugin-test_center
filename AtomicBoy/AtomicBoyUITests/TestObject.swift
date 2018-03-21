//
//  TestObject.swift
//  AtomicBoyUITests
//
//

import UIKit
import XCTest

class TestObject: NSObject {
    
    var testing : XCTestCase
    
    convenience init(testcase: XCTestCase) {
        self.init()
        self.testing = testcase
    }
    
    override init() {
        self.testing = XCTestCase()
        super.init()
    }
}
