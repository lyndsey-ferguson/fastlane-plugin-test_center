// Objective-C
#define QUICK_DISABLE_SHORT_SYNTAX 1

#import <Quick/Quick.h>

QuickSpecBegin(AutomicBoySpec)

describe(@"some tests", ^{
  it(@"sometimes suceeds", ^{
    if (arc4random_uniform(6) < 3) {
      XCTAssertTrue(false);
    }
  });
});

QuickSpecEnd
