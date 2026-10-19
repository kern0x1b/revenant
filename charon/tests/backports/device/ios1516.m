#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#import "check.h"
#import "ios1516-expectations.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *image_of_method(Class cls, SEL selector)
{
    Dl_info info;
    Method method = class_getInstanceMethod(cls, selector);
    return method && dladdr((const void *)method_getImplementation(method), &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing";
}

static void check_uuid_compare(void)
{
    NSMutableArray *ids = [NSMutableArray array];
    for (int index = 0; index < charon_uuid_count; index++)
        [ids addObject:[[NSUUID alloc] initWithUUIDString:@(charon_uuid_strings[index])]];
    CHECK_EQUAL(image_of_method([NSUUID class], @selector(compare:)), @"libFoundationBackports.dylib", "NSUUID compare: comes from the backports");
    int wrong = 0;
    for (int first = 0; first < charon_uuid_count; first++) {
        for (int second = 0; second < charon_uuid_count; second++) {
            if ([ids[first] compare:ids[second]] != charon_uuid_orders[first][second])
                wrong++;
        }
    }
    CHECK(wrong == 0, "every pair of UUIDs is ordered as the host orders it");
    int against_nil = 0;
    NSUUID *none = nil;
    for (int index = 0; index < charon_uuid_count; index++) {
        if ([ids[index] compare:none] != charon_uuid_against_nil[index])
            against_nil++;
    }
    CHECK(against_nil == 0, "a UUID against nil is ordered as the host orders it");
    CHECK([ids[0] compare:ids[0]] == NSOrderedSame, "a UUID is the same as itself");
}

static void check_orientation_update(void)
{
    UIViewController *controller = [[UIViewController alloc] init];
    CHECK([controller respondsToSelector:@selector(setNeedsUpdateOfSupportedInterfaceOrientations)], "a view controller answers the orientation update");
    CHECK([raised(^{ [controller setNeedsUpdateOfSupportedInterfaceOrientations]; }) isEqualToString:@"nothing"], "the orientation update raises nothing");
}

static void check_section_header_top_padding(void)
{
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) style:UITableViewStyleGrouped];
    CHECK(table.sectionHeaderTopPadding == UITableViewAutomaticDimension, "the padding above a section header starts automatic");
    table.sectionHeaderTopPadding = 0;
    CHECK(table.sectionHeaderTopPadding == 0, "a padding of zero is kept");
    table.sectionHeaderTopPadding = 12;
    CHECK(table.sectionHeaderTopPadding == 12, "a positive padding is kept");
    table.sectionHeaderTopPadding = -5;
    CHECK(table.sectionHeaderTopPadding == UITableViewAutomaticDimension, "a negative padding is automatic");
}

static void check_key_command_flags(void)
{
    UIKeyCommand *command = [UIKeyCommand keyCommandWithInput:@"a" modifierFlags:0 action:@selector(description)];
    CHECK(!command.wantsPriorityOverSystemBehavior && command.allowsAutomaticLocalization && command.allowsAutomaticMirroring,
          "a key command starts without priority and with automatic localization and mirroring");
    command.wantsPriorityOverSystemBehavior = YES;
    CHECK(command.wantsPriorityOverSystemBehavior && command.allowsAutomaticLocalization && command.allowsAutomaticMirroring, "the priority is kept on its own");
    command.allowsAutomaticLocalization = NO;
    command.allowsAutomaticMirroring = NO;
    CHECK(command.wantsPriorityOverSystemBehavior && !command.allowsAutomaticLocalization && !command.allowsAutomaticMirroring, "the two automatic flags are kept");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        check_uuid_compare();
        check_orientation_update();
        check_section_header_top_padding();
        check_key_command_flags();
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
