#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

static int failures = 0;

static void expect(BOOL ok, const char *what)
{
    if (!ok) {
        printf("failed: %s\n", what);
        failures++;
    }
}

int main(void)
{
    @autoreleasepool {
        NSFileManager *files = [NSFileManager defaultManager];
        NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        [files createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *png = [folder stringByAppendingPathComponent:@"picture.PNG"];
        NSString *blob = [folder stringByAppendingPathComponent:@"data.bin"];
        [files createFileAtPath:png contents:[NSData dataWithBytes:"\x89PNG" length:4] attributes:nil];
        [files createFileAtPath:blob contents:[NSData dataWithBytes:"xx" length:2] attributes:nil];

        NSError *error = nil;
        UNNotificationAttachment *picture = [UNNotificationAttachment attachmentWithIdentifier:@"picture"
                                                                                           URL:[NSURL fileURLWithPath:png]
                                                                                       options:nil error:&error];
        expect(picture != nil && error == nil, "a readable PNG is accepted");
        expect([picture.type isEqualToString:@"public.png"], "the extension gives the PNG type, whatever its case");
        expect([picture.identifier isEqualToString:@"picture"] && [picture.URL isEqual:[NSURL fileURLWithPath:png]],
               "the identifier and the URL are kept");

        error = nil;
        UNNotificationAttachment *hinted = [UNNotificationAttachment attachmentWithIdentifier:@"hinted"
                                                                                           URL:[NSURL fileURLWithPath:blob]
                                                                                       options:@{UNNotificationAttachmentOptionsTypeHintKey: @"public.jpeg"}
                                                                                         error:&error];
        expect(hinted != nil && error == nil && [hinted.type isEqualToString:@"public.jpeg"], "a type hint overrides the extension");

        error = nil;
        UNNotificationAttachment *unknown = [UNNotificationAttachment attachmentWithIdentifier:@"unknown"
                                                                                            URL:[NSURL fileURLWithPath:blob]
                                                                                        options:nil error:&error];
        expect(unknown == nil && [error.domain isEqualToString:UNErrorDomain] && error.code == UNErrorCodeAttachmentUnrecognizedType,
               "an unknown type without a hint is refused with UNErrorCodeAttachmentUnrecognizedType");

        error = nil;
        UNNotificationAttachment *missing = [UNNotificationAttachment attachmentWithIdentifier:@"missing"
                                                                                            URL:[NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"missing.png"]]
                                                                                        options:nil error:&error];
        expect(missing == nil && error.code == UNErrorCodeAttachmentInvalidURL, "a missing file is refused with UNErrorCodeAttachmentInvalidURL");

        error = nil;
        UNNotificationAttachment *directory = [UNNotificationAttachment attachmentWithIdentifier:@"directory"
                                                                                              URL:[NSURL fileURLWithPath:folder]
                                                                                          options:nil error:&error];
        expect(directory == nil && error.code == UNErrorCodeAttachmentInvalidURL, "a directory is refused with UNErrorCodeAttachmentInvalidURL");

        error = nil;
        UNNotificationAttachment *remote = [UNNotificationAttachment attachmentWithIdentifier:@"remote"
                                                                                           URL:[NSURL URLWithString:@"https://example.com/picture.png"]
                                                                                       options:nil error:&error];
        expect(remote == nil && error.code == UNErrorCodeAttachmentInvalidURL, "a remote URL is refused with UNErrorCodeAttachmentInvalidURL");

        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:picture requiringSecureCoding:YES error:nil];
        UNNotificationAttachment *copy = [NSKeyedUnarchiver unarchivedObjectOfClass:[UNNotificationAttachment class] fromData:archive error:nil];
        expect(copy != nil && [copy isEqual:picture] && [copy hash] == [picture hash], "an attachment survives a secure-coding round trip");
        expect([[picture copy] isEqual:picture], "a copy of an attachment equals it");

        [files removeItemAtPath:folder error:nil];
        if (failures == 0)
            printf("attachment ok\n");
    }
    return failures == 0 ? 0 : 1;
}
