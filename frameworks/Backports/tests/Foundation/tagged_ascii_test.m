#import "check.h"

@interface NSString (RevenantTaggedProbe)
+ (id)newTaggedNSStringWithASCIIBytes_:(const void *)bytes length_:(NSUInteger)length;
@end

@interface RevenantStorage : NSString
@end

@implementation RevenantStorage
- (NSUInteger)length
{
    return 0;
}

- (unichar)characterAtIndex:(NSUInteger)index
{
    return 0;
}
@end

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    SEL selector = @selector(newTaggedNSStringWithASCIIBytes_:length_:);
    revenant_check([NSString respondsToSelector:selector], "NSString answers the factory the Swift runtime sends", @"no");
    revenant_check(class_getClassMethod([NSString class], selector) != NULL, "the factory is a class method", @"absent");
    static const char *const samples[] = {"", "a", "abcdefg", "0123456789abcde", "path/to/item?query=1"};
    for (size_t index = 0; index < sizeof samples / sizeof samples[0]; index++) {
        id made = [NSString newTaggedNSStringWithASCIIBytes_:samples[index] length_:strlen(samples[index])];
        NSString *name = [NSString stringWithFormat:@"%zu bytes have no tagged form, so the caller makes its own string", strlen(samples[index])];
        revenant_check(revenant_negative ? made != nil : made == nil, [name UTF8String], [NSString stringWithFormat:@"%@", made]);
    }
    id inherited = [RevenantStorage newTaggedNSStringWithASCIIBytes_:"abc" length_:3];
    revenant_check(revenant_negative ? inherited != nil : inherited == nil, "a subclass that Swift allocates for its storage inherits the answer", [NSString stringWithFormat:@"%@", inherited]);
    return revenant_finish();
}
