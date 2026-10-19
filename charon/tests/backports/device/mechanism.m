#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "check.h"

@interface ClientQueryItem : NSURLQueryItem
@property (nonatomic, copy) NSString *extra;
@end

@implementation ClientQueryItem
- (instancetype)initWithName:(NSString *)name value:(NSString *)value
{
    if ((self = [super initWithName:name value:value]))
        _extra = @"extra";
    return self;
}
@end

@implementation NSURLQueryItem (Client)
- (NSString *)pair
{
    return [NSString stringWithFormat:@"%@=%@", self.name, self.value];
}
@end

static NSString *image_of(IMP implementation)
{
    Dl_info info;
    return dladdr((void *)implementation, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

int main(void)
{
    @autoreleasepool {
        Class item = [NSURLQueryItem class];
        CHECK(item != Nil, "weak class reference is bound");
        CHECK_EQUAL(@(class_getImageName(item)).lastPathComponent, @"libFoundationBackports.dylib", "class comes from the backports library");
        CHECK(NSClassFromString(@"NSURLQueryItem") == item, "runtime lookup finds the same class");
        ClientQueryItem *mine = [ClientQueryItem queryItemWithName:@"a" value:@"b"];
        CHECK_EQUAL(mine.extra, @"extra", "client subclass runs its own initializer");
        CHECK([mine isKindOfClass:item], "client subclass is a kind of the class");
        CHECK_EQUAL([mine pair], @"a=b", "client category on the class is attached");
        CHECK_EQUAL([[NSURLQueryItem queryItemWithName:@"x" value:nil] pair], @"x=(null)", "class works through the class method");
        CHECK([@"backports" containsString:@"port"], "missing method is added to an existing class");
        CHECK_EQUAL(image_of(class_getMethodImplementation([NSString class], @selector(containsString:))), @"libFoundationBackports.dylib", "added method comes from the backports library");
        CHECK(![NSString instancesRespondToSelector:@selector(charonMissing)], "nothing else is added");
        NSString *owner = image_of(class_getMethodImplementation([NSArray class], @selector(firstObject)));
        CHECK(![owner isEqualToString:@"libFoundationBackports.dylib"], "a method the system already has keeps its implementation");
        printf("firstObject implemented in %s\n", owner.UTF8String);
        CHECK_EQUAL([([NSArray arrayWithObjects:@1, @2, nil]) firstObject], @1, "system method still works");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
