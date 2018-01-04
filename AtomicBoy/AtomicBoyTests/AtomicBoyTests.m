//
//  AtomicBoyTests.m
//  AtomicBoyTests
//
//  Created by Lyndsey Ferguson on 10/25/17.
//  Copyright © 2017 Lyndsey Ferguson. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <stdlib.h>

@interface AtomicBoyTests : XCTestCase

@end

@implementation AtomicBoyTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    if (arc4random_uniform(6) < 3) {
        XCTAssertTrue(false);
    }
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
