// Reads the port's own objects, linked against the stand-in, and prints one line per thing that was
// asked of the release's primitives. The checker compares these lines with what the port must produce.
#import <UIKit/UIKit.h>
#import <stdio.h>

NSMutableArray *charon_take_calls(void);
void charon_reset_records(void);
NSString *charon_reported(NSString *);
void charon_plant(NSString *);
@class NSString;

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_plant(@(argv[1]));
        charon_reset_records();
        UIPasteboard *board = [[UIPasteboard alloc] init];

        // 1. -setItems:options: must hand the items to the release's own -setItems: and read both keys.
        [board setItems:@[@"one", @"two"] options:@{UIPasteboardOptionLocalOnly: @YES,
                                                       UIPasteboardOptionExpirationDate: (id)@"2030-01-01"}];
        for (NSString *call in charon_take_calls())
            printf("setItems:options: asked the release %s\n", charon_reported(call).UTF8String);
        NSArray *recorded = [board charonRecordedOptionsForTest];
        printf("setItems:options: recorded %s %s\n", charon_reported([recorded[0] description]).UTF8String,
               charon_reported([recorded[1] description]).UTF8String);

        // 2. -setObjects: must store a string and a URL through the release's own storer, one call each.
        charon_reset_records();
        [board setObjects:@[@"plain", [NSURL URLWithString:@"https://example.invalid/x"]]];
        for (NSString *call in charon_take_calls())
            printf("setObjects: asked the release %s\n", charon_reported(call).UTF8String);

        // 3. -setObjects:localOnly:expirationDate: must NOT reach the storer to record its options.
        charon_reset_records();
        [board setObjects:@[@"third"] localOnly:YES expirationDate:(id)@"2031-02-02"];
        for (NSString *call in charon_take_calls())
            printf("setObjects:localOnly: asked the release %s\n", charon_reported(call).UTF8String);
        NSArray *both = [board charonRecordedOptionsForTest];
        printf("setObjects:localOnly: recorded %s %s\n", charon_reported([both[0] description]).UTF8String,
               charon_reported([both[1] description]).UTF8String);
    }
    return 0;
}
