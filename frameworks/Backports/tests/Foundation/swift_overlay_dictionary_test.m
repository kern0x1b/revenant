#import "check.h"

@interface NSDictionary (RevenantSwiftOverlayProbe)
- (id)__swiftInitWithDictionary_NSDictionary:(NSDictionary *)other __attribute__((objc_method_family(init)));
- (id)__swift_objectForKeyedSubscript:(id)key;
@end

@interface NSMutableDictionary (RevenantSwiftOverlayProbe)
- (void)__swift_setObject:(id)object forKeyedSubscript:(id)key;
@end

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSMutableDictionary *mutable = [NSMutableDictionary dictionary];
    revenant_check([mutable respondsToSelector:@selector(__swift_setObject:forKeyedSubscript:)], "a mutable dictionary answers the setter the Swift overlay sends", @"no");
    revenant_check([mutable respondsToSelector:@selector(__swift_objectForKeyedSubscript:)], "a mutable dictionary answers the getter", @"no");
    revenant_check([[NSDictionary dictionary] respondsToSelector:@selector(__swift_objectForKeyedSubscript:)], "a dictionary answers the getter", @"no");
    for (int index = 0; index < 16; index++)
        [mutable __swift_setObject:@(index) forKeyedSubscript:[NSString stringWithFormat:@"k%02d", index]];
    revenant_check(mutable.count == 16, "sixteen keys are set through the setter", [NSString stringWithFormat:@"%lu", (unsigned long)mutable.count]);
    revenant_check([[mutable __swift_objectForKeyedSubscript:@"k07"] isEqual:@7], "the getter returns the value of a key", @"another value");
    revenant_check([mutable __swift_objectForKeyedSubscript:@"absent"] == nil, "the getter returns nil for an absent key", @"a value");
    [mutable __swift_setObject:nil forKeyedSubscript:@"k07"];
    revenant_check(revenant_negative ? mutable.count == 16 : mutable.count == 15, "a nil value removes the key", [NSString stringWithFormat:@"%lu keys", (unsigned long)mutable.count]);
    NSDictionary *plain = @{@"a": @1, @"b": @2};
    revenant_check([[plain __swift_objectForKeyedSubscript:@"b"] isEqual:@2], "an immutable dictionary answers the getter", @"another value");
    NSDictionary *copy = [[NSDictionary alloc] __swiftInitWithDictionary_NSDictionary:plain];
    revenant_check([copy isEqualToDictionary:plain], "the initializer copies a dictionary", [NSString stringWithFormat:@"%@", copy]);
    return revenant_finish();
}
