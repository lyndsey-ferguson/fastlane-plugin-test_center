//
//  KiwiTests.m
//  KiwiTests
//
//  Created by Lyndsey Ferguson on 6/16/19.
//  Copyright © 2019 Lyndsey Ferguson. All rights reserved.
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
