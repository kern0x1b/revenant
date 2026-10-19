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

        // A guest block boxed as id in a host NSArray. Building the array retains
        // each element: the host runtime must retain the guest block without
        // dereferencing its arm64 layout as if it were armv7.
        Adder add10 = makeAdder(10);
        NSArray *array = @[ @1.5, add10 ];

        // Read the block back out: host->guest must unwrap to the same guest block,
        // and the guest must invoke it directly.
        Adder fetched = array[1];
        int r = fetched(5);
        if (r != 15) { NSLog(@"blockid: guest invoke got %d, want 15", r); failures++; }

        // Identity across the boundary: the same guest block always maps to the
        // same object, so pointer comparison and use as a dictionary key work.
        if (fetched != add10) { NSLog(@"blockid: identity broke across boundary"); failures++; }
        NSDictionary *byBlock = @{ (id)add10 : @"ten" };
        NSString *tag = byBlock[(id)array[1]];
        if (![tag isEqualToString:@"ten"]) { NSLog(@"blockid: block-as-key lookup failed"); failures++; }

        // Lifetime: hold the block in a strong variable, drop the array, invoke afterwards.
        Adder survivor = array[1];
        array = nil;
        int r2 = survivor(7);
        if (r2 != 17) { NSLog(@"blockid: survivor invoke got %d, want 17", r2); failures++; }

        // Host invokes a guest block pulled from a host container.
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
