#import <Foundation/Foundation.h>

typedef int (^Adder)(int);

static Adder makeAdder(int base)
{
    return [^int(int x) { return base + x; } copy];
}

int main(void)
{
    @autoreleasepool {
        int failures = 0;

        Adder add10 = makeAdder(10);
        NSArray *array = @[ @1.5, add10 ];

        Adder fetched = array[1];
        int r = fetched(5);
        if (r != 15) { NSLog(@"blockid: guest invoke got %d, want 15", r); failures++; }

        if (fetched != add10) { NSLog(@"blockid: identity broke across boundary"); failures++; }
        NSDictionary *byBlock = @{ (id)add10 : @"ten" };
        NSString *tag = byBlock[(id)array[1]];
        if (![tag isEqualToString:@"ten"]) { NSLog(@"blockid: block-as-key lookup failed"); failures++; }

        Adder survivor = array[1];
        array = nil;
        int r2 = survivor(7);
        if (r2 != 17) { NSLog(@"blockid: survivor invoke got %d, want 17", r2); failures++; }

        __block int hostSum = 0;
        NSArray *blocks = @[ makeAdder(100), makeAdder(200) ];
        [blocks enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            Adder a = obj;
            hostSum += a((int)idx);
        }];
        if (hostSum != 301) { NSLog(@"blockid: host-driven invoke got %d, want 301", hostSum); failures++; }

        NSLog(@"blockid: %@ (failures=%d)", failures == 0 ? @"PASS" : @"FAIL", failures);
        return failures;
    }
}
