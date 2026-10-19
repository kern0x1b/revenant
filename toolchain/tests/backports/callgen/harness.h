#import <Foundation/Foundation.h>

typedef struct RevenantCallLog RevenantCallLog;

extern void RevenantCallOpen(const char *path);
extern void RevenantCallClose(void);

extern RevenantCallLog *RevenantCallLogCreate(void);
extern Class RevenantCallClass(RevenantCallLog *log, NSString *name);
extern id RevenantCallInstance(RevenantCallLog *log, Class cls);
extern void RevenantCallRemember(RevenantCallLog *log, Class cls, id instance);
extern BOOL RevenantCallSelector(RevenantCallLog *log, Class cls, id receiver, SEL selector);
extern void RevenantCallNoted(RevenantCallLog *log, Class cls, SEL selector, id value);
extern void RevenantCallRaised(RevenantCallLog *log, Class cls, SEL selector, NSException *raised);
extern void RevenantCallProperty(RevenantCallLog *log, Class cls, id object, NSString *name,
                               NSString *getter, NSString *setter);
extern void RevenantCallCrashed(RevenantCallLog *log, const char *label, int status);

extern int RevenantCallIsolated(const char *label, void (*run)(RevenantCallLog *), RevenantCallLog *log);

extern unsigned RevenantCallReport(NSString *title);
