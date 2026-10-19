#import <Foundation/Foundation.h>
#ifdef CHARON_PORT
#import "CharonPDFKit.h"
#else
#import <PDFKit/PDFKit.h>
#endif
#include <stdio.h>

static int notifications = 0;

static void counted(NSNotification *note)
{
    (void)note;
    notifications++;
}

static void report(NSString *name, PDFDocument *doc, NSString *tag)
{
    printf("%s.%s.isEncrypted=%d\n", name.UTF8String, tag.UTF8String, (int)doc.isEncrypted);
    printf("%s.%s.isLocked=%d\n", name.UTF8String, tag.UTF8String, (int)doc.isLocked);
    printf("%s.%s.pageCount=%lu\n", name.UTF8String, tag.UTF8String, (unsigned long)doc.pageCount);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            NSString *path = @(argv[i]);
            NSString *name = path.lastPathComponent;
            NSURL *url = [NSURL fileURLWithPath:path];

            PDFDocument *doc = [[PDFDocument alloc] initWithURL:url];
            if (doc == nil) {
                printf("%s.open=nil\n", name.UTF8String);
                continue;
            }
            report(name, doc, @"opened");

            if (doc.isLocked) {
                BOOL none = [doc unlockWithPassword:nil];
                printf("%s.unlockNil=%d\n", name.UTF8String, (int)none);
                printf("%s.afterNil.isLocked=%d\n", name.UTF8String, (int)doc.isLocked);
            }

            notifications = 0;
            id observer = [[NSNotificationCenter defaultCenter] addObserverForName:PDFDocumentDidUnlockNotification
                                                                            object:doc queue:nil usingBlock:^(NSNotification *n) { counted(n); }];
            BOOL wrong = [doc unlockWithPassword:@"nope"];
            printf("%s.unlockWrong=%d\n", name.UTF8String, (int)wrong);
            printf("%s.unlockWrong.notifications=%d\n", name.UTF8String, notifications);
            report(name, doc, @"afterWrong");

            notifications = 0;
            BOOL right = [doc unlockWithPassword:@"secret"];
            printf("%s.unlockRight=%d\n", name.UTF8String, (int)right);
            printf("%s.unlockRight.notifications=%d\n", name.UTF8String, notifications);
            report(name, doc, @"afterRight");
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        }

        PDFDocument *empty = [[PDFDocument alloc] init];
        printf("empty.isEncrypted=%d\n", (int)empty.isEncrypted);
        printf("empty.isLocked=%d\n", (int)empty.isLocked);
        printf("empty.unlock=%d\n", (int)[empty unlockWithPassword:@"x"]);
        printf("empty.pageCount=%lu\n", (unsigned long)empty.pageCount);
    }
    return 0;
}
