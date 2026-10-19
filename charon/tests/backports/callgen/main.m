//
//  main.m
//  The generated call test's entry point, on the host and in the port alike.
//
//  It walks the case table the generator wrote — a label and a function each — and reports what
//  the process answered. The same file runs in a Mac Catalyst binary, where the calls go to the
//  system's own Intents.framework and the run is the oracle, and in a charon port at 6.1.3, where
//  they go to libIntentsBackports; nothing in it knows which, because the names it looks up are
//  the names the registry carries.
//
//  Exit status is zero only when every class and every member the registry carries is answered
//  and every call returned.
//

#import "harness.h"

#import <Foundation/Foundation.h>

// One case: the label that names it in the report, and the function that performs it.
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
