#import <UIKit/UIKit.h>
#import <stdio.h>

NSMutableArray *revenant_take_calls(void);
void revenant_reset_records(void);
NSString *revenant_reported(NSString *);
void revenant_plant(NSString *);
@class NSString;

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            revenant_plant(@(argv[1]));
        revenant_reset_records();
        UIPasteboard *board = [[UIPasteboard alloc] init];

        [board setItems:@[@"one", @"two"] options:@{UIPasteboardOptionLocalOnly: @YES,
                                                       UIPasteboardOptionExpirationDate: (id)@"2030-01-01"}];
        for (NSString *call in revenant_take_calls())
            printf("setItems:options: asked the release %s\n", revenant_reported(call).UTF8String);
        NSArray *recorded = [board revenantRecordedOptionsForTest];
        printf("setItems:options: recorded %s %s\n", revenant_reported([recorded[0] description]).UTF8String,
               revenant_reported([recorded[1] description]).UTF8String);

        revenant_reset_records();
        [board setObjects:@[@"plain", [NSURL URLWithString:@"https://example.invalid/x"]]];
        for (NSString *call in revenant_take_calls())
            printf("setObjects: asked the release %s\n", revenant_reported(call).UTF8String);

        revenant_reset_records();
        [board setObjects:@[@"third"] localOnly:YES expirationDate:(id)@"2031-02-02"];
        for (NSString *call in revenant_take_calls())
            printf("setObjects:localOnly: asked the release %s\n", revenant_reported(call).UTF8String);
        NSArray *both = [board revenantRecordedOptionsForTest];
        printf("setObjects:localOnly: recorded %s %s\n", revenant_reported([both[0] description]).UTF8String,
               revenant_reported([both[1] description]).UTF8String);
    }
    return 0;
}
