#import <Foundation/Foundation.h>
#import <CoreNFC/CoreNFC.h>
#include <stdio.h>

static void show(const char *label, NSUserActivity *activity)
{
    NFCNDEFMessage *message = activity.ndefMessagePayload;
    NFCNDEFPayload *record = message.records.firstObject;
    printf("%s: class %s, records %lu, format %ld, type %lu, identifier %lu, payload %lu, length %lu\n", label,
           NSStringFromClass([message class]).UTF8String, (unsigned long)message.records.count,
           (long)record.typeNameFormat, (unsigned long)record.type.length, (unsigned long)record.identifier.length,
           (unsigned long)record.payload.length, (unsigned long)message.length);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        show("activity", [[NSUserActivity alloc] initWithActivityType:@"org.charon.nfc.probe"]);
        show("other type", [[NSUserActivity alloc] initWithActivityType:@"com.example.other"]);
        NSUserActivity *withInfo = [[NSUserActivity alloc] initWithActivityType:@"org.charon.nfc.probe"];
        withInfo.userInfo = @{@"key": @"value"};
        show("with user info", withInfo);
        NSUserActivity *activity = [[NSUserActivity alloc] initWithActivityType:@"org.charon.nfc.probe"];
        printf("each read is a message of its own: %d\n", activity.ndefMessagePayload != activity.ndefMessagePayload);
    }
    return 0;
}
