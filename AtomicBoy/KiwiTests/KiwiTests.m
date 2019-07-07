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

describe(@"KiwiDemoTests", ^{
    context(@"test1", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

describe(@"KiwiDemoTests", ^{
    context(@"test2", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

describe(@"KiwiDemoTests", ^{
    context(@"test3", ^{
        it(@"2 + 2 = 5", ^{
            [[theValue(2 + 2) should] equal:theValue(5)];
        });
    });
});

SPEC_END

SPEC_BEGIN(SmallBirdTests)

describe(@"(SmallBirdTests)", ^{
    context(@"test", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

describe(@"(SmallBirdTests)", ^{
    context(@"test1", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

describe(@"(SmallBirdTests)", ^{
    context(@"test2", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

describe(@"(SmallBirdTests)", ^{
    context(@"test3", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

describe(@"(SmallBirdTests)", ^{
    context(@"test4", ^{
        it(@"2 + 2 = 5", ^{
            [[theValue(2 + 2) should] equal:theValue(5)];
        });
    });
});

SPEC_END


SPEC_BEGIN(PumpkinTests)

describe(@"PumpkinTests", ^{
    context(@"test", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

describe(@"PumpkinTests", ^{
    context(@"test1", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

describe(@"PumpkinTests", ^{
    context(@"test2", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

describe(@"PumpkinTests", ^{
    context(@"test3", ^{
        it(@"2 + 2 = 5", ^{
            [[theValue(2 + 2) should] equal:theValue(5)];
        });
    });
});

SPEC_END


SPEC_BEGIN(CruddogTests)

describe(@"CruddogTests", ^{
    context(@"test", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

describe(@"CruddogTests", ^{
    context(@"test1", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

describe(@"CruddogTests", ^{
    context(@"test2", ^{
        it(@"2 + 2 = 4", ^{
            [[theValue(2 + 2) should] equal:theValue(4)];
        });
    });
});

describe(@"CruddogTests", ^{
    context(@"test3", ^{
        it(@"2 + 2 = 5", ^{
            [[theValue(2 + 2) should] equal:theValue(5)];
        });
    });
});

SPEC_END
