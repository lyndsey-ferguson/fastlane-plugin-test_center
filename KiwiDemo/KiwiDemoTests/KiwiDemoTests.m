//
//  KiwiDemoTests.m
//  KiwiDemoTests
//
//  Created by Yousef Hamza on 5/12/19.
//  Copyright © 2019 Instabug. All rights reserved.
//

#import <Kiwi/Kiwi.h>

SPEC_BEGIN(KiwiDemoTests)

describe(@"KiwiDemoTests", ^{
    context(@"test", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

SPEC_END
