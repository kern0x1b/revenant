#import "harness.h"

#import <Foundation/Foundation.h>

typedef struct {
    const char *label;
    void (*run)(CharonCallLog *log);
} CharonCallEntry;

extern const CharonCallEntry charon_call_cases[];
extern const unsigned charon_call_case_count;

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        NSString *title = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"calls";
        NSString *path = argc > 2 ? [NSString stringWithUTF8String:argv[2]] : @"calls.log";
        CharonCallOpen([path fileSystemRepresentation]);
        CharonCallLog *log = CharonCallLogCreate();
        for (unsigned index = 0; index < charon_call_case_count; index++) {
            CharonCallIsolated(charon_call_cases[index].label, charon_call_cases[index].run, log);
        }
        return (int)CharonCallReport(title);
    }
}
