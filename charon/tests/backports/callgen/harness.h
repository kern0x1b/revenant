#import <Foundation/Foundation.h>

typedef struct CharonCallLog CharonCallLog;

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

extern int CharonCallIsolated(const char *label, void (*run)(CharonCallLog *), CharonCallLog *log);

extern unsigned CharonCallReport(NSString *title);
