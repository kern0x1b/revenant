#import "harness.h"

#import <Foundation/Foundation.h>

typedef struct {
    const char *label;
    void (*run)(RevenantCallLog *log);
} RevenantCallEntry;

extern const RevenantCallEntry revenant_call_cases[];
extern const unsigned revenant_call_case_count;

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        NSString *title = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"calls";
        NSString *path = argc > 2 ? [NSString stringWithUTF8String:argv[2]] : @"calls.log";
        RevenantCallOpen([path fileSystemRepresentation]);
        RevenantCallLog *log = RevenantCallLogCreate();
        for (unsigned index = 0; index < revenant_call_case_count; index++) {
            RevenantCallIsolated(revenant_call_cases[index].label, revenant_call_cases[index].run, log);
        }
        return (int)RevenantCallReport(title);
    }
}
