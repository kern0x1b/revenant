// The classes a release carries without exporting them, which the port exports as aliases
// (packages/a/apple-backports/charon_alias.h): NSTextTab until iOS 7.0 and NSTextList until 9.0.
// The name links, +class is the release's class, what is made is the release's class, the
// class answers every question about itself as the release's class does, a subclass inherits
// the release's class, and the categories written on the name reach the release's class
// through the library's loader.
//
// Built with packages/a/apple-backports/attach.c beside it, the process is also an image with
// aliases of its own, of two more classes 6.1.3 carries in UIFoundation without exporting:
// NSTextBlock, with a category that writes a method the release has and one it lacks, and
// NSTextTable, whose subclass here has a +load, so the runtime lays the alias out before the
// loader of this image runs.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <asl.h>
#include <dlfcn.h>
#include <unistd.h>
#import "check.h"
#import "../../../packages/a/apple-backports/charon_alias.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wnonnull"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface NSTextBlock : NSObject
- (UIColor *)backgroundColor;
- (void)setBackgroundColor:(UIColor *)color;
@end

@interface NSTextBlock (TextAliasProbe)
+ (NSInteger)textAliasClassProbe;
- (NSInteger)textAliasProbe;
@end

@interface NSTextTable : NSTextBlock
- (NSUInteger)numberOfColumns;
@end

CHARON_ALIAS(NSTextBlock)
CHARON_ALIAS(NSTextTable)

@implementation NSTextBlock (TextAliasProbe)

+ (NSInteger)textAliasClassProbe
{
    return 43;
}

- (UIColor *)backgroundColor
{
    return [UIColor redColor];
}

- (NSInteger)textAliasProbe
{
    return 42;
}

@end

@interface TextAliasList : NSTextList {
@public
    NSInteger _mark[4];
}
@end

@implementation TextAliasList

- (NSInteger)startingItemNumber
{
    return [super startingItemNumber] + 1000;
}

@end

@interface TextAliasTab : NSTextTab {
@public
    NSInteger _mark[4];
}
@end

@implementation TextAliasTab
@end

@interface TextAliasBlock : NSTextBlock {
@public
    NSInteger _mark[4];
}
@end

@implementation TextAliasBlock
@end

@interface TextAliasTable : NSTextTable {
@public
    NSInteger _mark[4];
}
@end

@implementation TextAliasTable

+ (void)load
{
}

@end

static NSString *image_of(const void *address)
{
    Dl_info info;
    return address && dladdr(address, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *image_of_method(Method method)
{
    return method ? image_of((const void *)method_getImplementation(method)) : @"none";
}

static BOOL own_class_method(Class cls, SEL selector)
{
    unsigned count = 0;
    Method *methods = cls ? class_copyMethodList(object_getClass(cls), &count) : NULL;
    BOOL found = NO;
    for (unsigned index = 0; index < count && !found; index++)
        found = method_getName(methods[index]) == selector;
    free(methods);
    return found;
}

static void check_text_tab(void)
{
    Class release = objc_getClass("NSTextTab");
    CHECK(release != Nil, "NSTextTab: the release carries the class");
    CHECK_EQUAL(image_of((__bridge const void *)release), @"UIFoundation", "NSTextTab: the class by name is UIFoundation's");
    CHECK([NSTextTab class] == release, "NSTextTab: the linked name answers the release's class");
    NSTextTab *tab = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight location:40 options:nil];
    CHECK(object_getClass(tab) == release && [tab isKindOfClass:[NSTextTab class]], "NSTextTab: a tab made through the name is the release's");
    CHECK_EQUAL(image_of_method(class_getClassMethod(release, @selector(columnTerminatorsForLocale:))), @"libUIKitBackports.dylib",
                "NSTextTab: the category's class method is on the release's class");
    CHECK([[NSTextTab columnTerminatorsForLocale:nil] characterIsMember:'.'], "NSTextTab: the class method answers through the name");
    CHECK(!own_class_method(objc_getClass("CharonNSTextTab"), @selector(load)), "NSTextTab: the alias has no +load of its own");
}

static void check_text_list(void)
{
    Class release = objc_getClass("NSTextList");
    SEL three = @selector(initWithMarkerFormat:options:startingItemNumber:);
    CHECK(release != Nil, "NSTextList: the release carries the class");
    CHECK_EQUAL(image_of((__bridge const void *)release), @"UIFoundation", "NSTextList: the class by name is UIFoundation's");
    CHECK([NSTextList class] == release, "NSTextList: the linked name answers the release's class");
    CHECK_EQUAL(image_of_method(class_getInstanceMethod(release, @selector(initWithMarkerFormat:options:))), @"UIFoundation",
                "NSTextList: the two-argument initializer is the release's own");
    CHECK_EQUAL(image_of_method(class_getInstanceMethod(release, three)), @"libUIKitBackports.dylib",
                "NSTextList: the category's three-argument initializer is on the release's class");
    CHECK(objc_getClass("CharonTextListInit16") == Nil, "NSTextList: no class of the library adds the initializer by name");
    // The format as a string: iOS 6 exports none of the NSTextListMarker constants.
    NSTextList *list = [[NSTextList alloc] initWithMarkerFormat:@"{decimal}" options:0 startingItemNumber:5];
    CHECK(object_getClass(list) == release && [list isKindOfClass:[NSTextList class]], "NSTextList: a list made through the name is the release's");
    CHECK(list.startingItemNumber == 5 && [list.markerFormat isEqualToString:@"{decimal}"], "NSTextList: the list keeps its format and its starting number");
}

// What the name answers about itself, sent as an application sends it, against what the
// release's class answers.
#define CHECK_INTROSPECTION(Name, member, protocol)                                                                       \
    do {                                                                                                               \
        Class release = objc_getClass(#Name);                                                                          \
        CHECK(class_getSuperclass(objc_getClass("Charon" #Name)) == release, #Name ": the alias is a subclass of the release's class"); \
        CHECK([Name instancesRespondToSelector:member] && [release instancesRespondToSelector:member],                \
              #Name ": instancesRespondToSelector: answers the release's member");                                    \
        CHECK([Name instanceMethodForSelector:member] == [release instanceMethodForSelector:member],                  \
              #Name ": instanceMethodForSelector: is the release's implementation");                                  \
        CHECK([[Name instanceMethodSignatureForSelector:member] isEqual:[release instanceMethodSignatureForSelector:member]], \
              #Name ": instanceMethodSignatureForSelector: is the release's signature");                              \
        CHECK([release conformsToProtocol:protocol] && [Name conformsToProtocol:protocol],                            \
              #Name ": conformsToProtocol: answers the release's protocol");                                          \
        CHECK([Name respondsToSelector:@selector(instancesRespondToSelector:)] && ![Name respondsToSelector:@selector(textAliasAbsent)], \
              #Name ": respondsToSelector: answers for the class");                                                   \
        CHECK([Name methodForSelector:@selector(new)] == [release methodForSelector:@selector(new)],                   \
              #Name ": methodForSelector: is the release's implementation");                                          \
        CHECK([Name superclass] == [release superclass], #Name ": superclass is the release's superclass");           \
        CHECK([Name isSubclassOfClass:release] && ![Name isSubclassOfClass:[NSString class]],                         \
              #Name ": isSubclassOfClass: answers as the release's class");                                           \
        CHECK([Name isEqual:release] && [Name hash] == [release hash], #Name ": isEqual: and hash are the release's class"); \
        CHECK_EQUAL([Name description], @#Name, #Name ": description is the release's name");                          \
        CHECK_EQUAL(NSStringFromClass([Name class]), @#Name, #Name ": NSStringFromClass of +class is the release's name"); \
    } while (0)

// A subclass of the name inherits the release's class and is laid out after its instance variables.
static void check_subclasses(void)
{
    Class list = objc_getClass("NSTextList"), tab = objc_getClass("NSTextTab");
    CHECK(class_getSuperclass([TextAliasList class]) == objc_getClass("CharonNSTextList") && [TextAliasList superclass] == list,
          "subclass of NSTextList: its superclass is the release's class");
    CHECK(class_getInstanceSize([TextAliasList class]) >= class_getInstanceSize(list) + sizeof(NSInteger) * 4,
          "subclass of NSTextList: its instance variables come after the release's");
    TextAliasList *made = [[TextAliasList alloc] initWithMarkerFormat:@"{disc}" options:0];
    CHECK(object_getClass(made) == [TextAliasList class] && [TextAliasList class] == [TextAliasList self], "subclass of NSTextList: +alloc makes the subclass");
    CHECK([made isKindOfClass:[NSTextList class]] && [made isKindOfClass:list], "subclass of NSTextList: an instance is kind of the release's class");
    for (NSInteger index = 0; index < 4; index++)
        made->_mark[index] = 7 + index;
    made.startingItemNumber = 3;
    CHECK([made.markerFormat isEqualToString:@"{disc}"] && made.startingItemNumber == 1003 && made->_mark[0] == 7 && made->_mark[3] == 10,
          "subclass of NSTextList: the release's state, the override through super and the subclass's own state are apart");
    TextAliasList *numbered = [[TextAliasList alloc] initWithMarkerFormat:@"{decimal}" options:0 startingItemNumber:5];
    CHECK(object_getClass(numbered) == [TextAliasList class] && numbered.startingItemNumber == 1005,
          "subclass of NSTextList: the category's initializer makes the subclass");
    CHECK([TextAliasList instancesRespondToSelector:@selector(markerFormat)] && [TextAliasList conformsToProtocol:@protocol(NSCoding)] == [list conformsToProtocol:@protocol(NSCoding)],
          "subclass of NSTextList: introspection reaches the release's class");
    CHECK([[TextAliasList new] isMemberOfClass:[TextAliasList class]], "subclass of NSTextList: +new makes the subclass");

    TextAliasTab *stop = [[TextAliasTab alloc] initWithTextAlignment:NSTextAlignmentRight location:40 options:nil];
    stop->_mark[0] = 9;
    CHECK(object_getClass(stop) == [TextAliasTab class] && [stop isKindOfClass:tab] && stop.location == 40 && stop.alignment == NSTextAlignmentRight && stop->_mark[0] == 9,
          "subclass of NSTextTab: +alloc makes the subclass, and it inherits the release's tab");
}

// This image's own aliases: a method the release has stays the release's for a subclass, one it
// lacks is given to the release's class; an alias laid out before the loader ran stays under NSObject.
static void check_loader(void)
{
    Class block = objc_getClass("NSTextBlock"), table = objc_getClass("NSTextTable");
    CHECK(block && table && [NSTextBlock class] == block && [NSTextTable class] == table, "this image's aliases: +class is the release's class");
    CHECK(class_getSuperclass(objc_getClass("CharonNSTextBlock")) == block, "NSTextBlock: the alias is a subclass of the release's class");
    TextAliasBlock *made = [[TextAliasBlock alloc] init];
    made.backgroundColor = [UIColor blueColor];
    made->_mark[0] = 11;
    CHECK_EQUAL(image_of((const void *)class_getMethodImplementation([TextAliasBlock class], @selector(backgroundColor))), @"UIFoundation",
                "NSTextBlock: for a subclass, a method the release has is the release's, not the category's copy");
    CHECK_EQUAL(made.backgroundColor, [UIColor blueColor], "NSTextBlock: a subclass keeps the colour the release's setter stored");
    CHECK(made->_mark[0] == 11 && [made textAliasProbe] == 42 && [(NSTextBlock *)[[NSTextBlock alloc] init] textAliasProbe] == 42,
          "NSTextBlock: a method the release lacks is given to the release's class, and a subclass has it");
    CHECK_EQUAL(image_of_method(class_getInstanceMethod(block, @selector(textAliasProbe))), @"textalias", "NSTextBlock: the method given is the category's");

    CHECK(class_getSuperclass(objc_getClass("CharonNSTextTable")) == [NSObject class], "NSTextTable: an alias laid out before the loader stays under NSObject");
    CHECK(object_getClass([[NSTextTable alloc] init]) == table && [NSTextTable instancesRespondToSelector:@selector(numberOfColumns)],
          "NSTextTable: the alias still answers as the release's class");
    CHECK([NSTextTable textAliasClassProbe] == 43 && [table textAliasClassProbe] == 43,
          "NSTextTable: a class method of the release's class is forwarded to it");
    CHECK([[TextAliasTable alloc] init] != nil && ![TextAliasTable instancesRespondToSelector:@selector(numberOfColumns)],
          "NSTextTable: its subclass does not inherit the release's class");
    aslmsg query = asl_new(ASL_TYPE_QUERY);
    asl_set_query(query, ASL_KEY_PID, [NSString stringWithFormat:@"%d", getpid()].UTF8String, ASL_QUERY_OP_EQUAL);
    asl_set_query(query, ASL_KEY_MSG, "CharonNSTextTable was laid out before the library's loader ran", ASL_QUERY_OP_EQUAL | ASL_QUERY_OP_SUBSTRING);
    aslresponse found = asl_search(NULL, query);
    BOOL logged = found && aslresponse_next(found) != NULL;
    aslresponse_free(found);
    asl_free(query);
    CHECK(logged, "NSTextTable: the log names the alias laid out before the loader");

    // The one public function that changes a superclass, on this alias the runtime has already laid out:
    // it links the release's class in, and the size stays NSObject's, so the subclass laid out after it
    // has its instance variables where the release's are. Nothing is made of either afterwards.
    Class proxy = objc_getClass("CharonNSTextTable");
    size_t before = class_getInstanceSize(proxy);
    ptrdiff_t mark = ivar_getOffset(class_getInstanceVariable([TextAliasTable class], "_mark"));
    class_setSuperclass(proxy, table);
    printf("measured: class_setSuperclass on a laid-out alias: superclass %s, alias size %zu (before %zu), release size %zu, subclass ivar at %td\n",
           class_getName(class_getSuperclass(proxy)), class_getInstanceSize(proxy), before, class_getInstanceSize(table), mark);
    CHECK(class_getSuperclass(proxy) == table && class_getInstanceSize(proxy) == before && before == class_getInstanceSize([NSObject class]),
          "class_setSuperclass: the alias is linked under the release's class and keeps NSObject's size");
    CHECK(mark < (ptrdiff_t)class_getInstanceSize(table) && ivar_getOffset(class_getInstanceVariable([TextAliasTable class], "_mark")) == mark,
          "class_setSuperclass: the subclass's instance variables stay inside the release's");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_text_tab();
        check_text_list();
        CHECK_INTROSPECTION(NSTextList, @selector(markerFormat), @protocol(NSCoding));
        CHECK_INTROSPECTION(NSTextTab, @selector(location), @protocol(NSCoding));
        check_subclasses();
        check_loader();
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
