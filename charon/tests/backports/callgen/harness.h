//
//  harness.h
//  The runtime of the generated call test.
//
//  The test exists because the gate cannot see a member with no accessor: check_registry in
//  modules/apple/backports.lua marks a member built as soon as its owner class is exported, so a
//  class with twelve properties and no accessors at all is green there. What is asked here is
//  asked of the runtime, and each of it in a process of its own:
//
//    CharonCallClass       the class, by name. A name the registry carries and the process does
//                          not have is recorded as missing, not skipped: the whole point is that
//                          the library answers for it.
//    CharonCallSelector    the respondsToSelector: check, asked of the receiver the call goes to.
//                          NO is missing, and it is the check a declaration, a synthesised
//                          property and a missing accessor do not all pass.
//    CharonCallNoted       what a call answered.
//    CharonCallRaised      what a call refused, by raising. That is an answer: the system's own
//                          +[INAccountTypeResolutionResult confirmationRequiredWithAccountTypeToConfirm:]
//                          raises NSInvalidArgumentException for a value it will not ask a user to
//                          confirm (measured on the host, 2026-09-27), and a test that called that
//                          a crash would be reporting the API's refusal as a defect.
//    CharonCallProperty    a property, by the accessor its declaration names. A property is called
//                          through its getter, which is often not its name: INPerson's
//                          contactSuggestion is declared `getter=isContactSuggestion` and
//                          INRideCompletionStatus' completed is `getter=isCompleted`, and asking
//                          for the name rather than the accessor is a question no caller ever
//                          asks - which is how the host run came to report six members of Apple's
//                          own framework as missing when it has every one of them (measured
//                          2026-09-27). The getter is asked for, read, the setter asked for, a
//                          neutral value written, and the value read back.
//
//  **Every case runs in a forked child.** A call of a thousand can take the process down, and one
//  that does must not take the other thousand with it: the child's exit status is the verdict for
//  that one member, and the run goes on. That is also the only way "it must not crash" is a
//  per-member answer rather than a single yes or no about the whole test.
//
//  The events are one line each, appended by the child to a shared file, so the parent needs no
//  shared memory and the file is the digest the two runs are compared with.
//

#import <Foundation/Foundation.h>

typedef struct CharonCallLog CharonCallLog;

// Where the events go: one line per present class, answered selector, answer, refusal, missing
// name and crash, appended as they happen. Opened once, by the parent, before any child runs.
extern void CharonCallOpen(const char *path);
extern void CharonCallClose(void);

extern CharonCallLog *CharonCallLogCreate(void);
extern Class CharonCallClass(CharonCallLog *log, NSString *name);
extern id CharonCallInstance(CharonCallLog *log, Class cls);
extern void CharonCallRemember(CharonCallLog *log, Class cls, id instance);
extern BOOL CharonCallSelector(CharonCallLog *log, Class cls, id receiver, SEL selector);
extern void CharonCallNoted(CharonCallLog *log, Class cls, SEL selector, id value);
extern void CharonCallRaised(CharonCallLog *log, Class cls, SEL selector, NSException *raised);
extern void CharonCallProperty(CharonCallLog *log, Class cls, id object, NSString *name,
                               NSString *getter, NSString *setter);
extern void CharonCallCrashed(CharonCallLog *log, const char *label, int status);

// One case, in a child of its own: 0 when the case returned, and the wait status when it did not.
extern int CharonCallIsolated(const char *label, void (*run)(CharonCallLog *), CharonCallLog *log);

// The whole run: every case of the table, and the report. Returns the exit status.
extern unsigned CharonCallReport(NSString *title);
