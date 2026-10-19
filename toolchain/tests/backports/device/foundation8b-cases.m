#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <sys/mman.h>
#import "foundation8b-cases.h"

extern void (^const NSDataDeallocatorVM)(void *bytes, NSUInteger length);
extern void (^const NSDataDeallocatorUnmap)(void *bytes, NSUInteger length);
extern void (^const NSDataDeallocatorFree)(void *bytes, NSUInteger length);
extern void (^const NSDataDeallocatorNone)(void *bytes, NSUInteger length);
extern int NSExtensionMain(int argc, char *argv[]);

static NSString *wait_result(NSString *(^block)(void (^done)(NSString *)))
{
    __block NSString *result = nil;
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    block(^(NSString *value) {
        result = value;
        dispatch_semaphore_signal(finished);
    });
    if (dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)))
        return @"timed out";
    return result;
}

void foundation8b_run(Foundation8bRecorder record)
{
    NSArray *names = @[@"NSMetadataUbiquitousItemDownloadingStatusKey", @"NSMetadataUbiquitousItemDownloadingStatusNotDownloaded", @"NSMetadataUbiquitousItemDownloadingStatusDownloaded", @"NSMetadataUbiquitousItemDownloadingStatusCurrent",
                       @"NSMetadataUbiquitousItemDownloadingErrorKey", @"NSMetadataUbiquitousItemUploadingErrorKey", @"NSMetadataQueryUpdateAddedItemsKey", @"NSMetadataQueryUpdateChangedItemsKey", @"NSMetadataQueryUpdateRemovedItemsKey",
                       @"NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope", @"NSMetadataItemContentTypeKey", @"NSMetadataItemContentTypeTreeKey", @"NSMetadataUbiquitousItemDownloadRequestedKey", @"NSMetadataUbiquitousItemIsExternalDocumentKey",
                       @"NSMetadataUbiquitousItemContainerDisplayNameKey", @"NSMetadataUbiquitousItemURLInLocalContainerKey", @"NSMetadataUbiquitousItemIsSharedKey", @"NSMetadataUbiquitousSharedItemCurrentUserRoleKey",
                       @"NSMetadataUbiquitousSharedItemCurrentUserPermissionsKey", @"NSMetadataUbiquitousSharedItemOwnerNameComponentsKey", @"NSMetadataUbiquitousSharedItemMostRecentEditorNameComponentsKey", @"NSMetadataUbiquitousSharedItemRoleOwner",
                       @"NSMetadataUbiquitousSharedItemRoleParticipant", @"NSMetadataUbiquitousSharedItemPermissionsReadOnly", @"NSMetadataUbiquitousSharedItemPermissionsReadWrite", @"NSExtensionHostDidBecomeActiveNotification",
                       @"NSExtensionHostDidEnterBackgroundNotification", @"NSExtensionHostWillEnterForegroundNotification", @"NSExtensionHostWillResignActiveNotification"];
    NSArray *values = @[NSMetadataUbiquitousItemDownloadingStatusKey, NSMetadataUbiquitousItemDownloadingStatusNotDownloaded, NSMetadataUbiquitousItemDownloadingStatusDownloaded, NSMetadataUbiquitousItemDownloadingStatusCurrent,
                        NSMetadataUbiquitousItemDownloadingErrorKey, NSMetadataUbiquitousItemUploadingErrorKey, NSMetadataQueryUpdateAddedItemsKey, NSMetadataQueryUpdateChangedItemsKey, NSMetadataQueryUpdateRemovedItemsKey,
                        NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope, NSMetadataItemContentTypeKey, NSMetadataItemContentTypeTreeKey, NSMetadataUbiquitousItemDownloadRequestedKey, NSMetadataUbiquitousItemIsExternalDocumentKey,
                        NSMetadataUbiquitousItemContainerDisplayNameKey, NSMetadataUbiquitousItemURLInLocalContainerKey, NSMetadataUbiquitousItemIsSharedKey, NSMetadataUbiquitousSharedItemCurrentUserRoleKey,
                        NSMetadataUbiquitousSharedItemCurrentUserPermissionsKey, NSMetadataUbiquitousSharedItemOwnerNameComponentsKey, NSMetadataUbiquitousSharedItemMostRecentEditorNameComponentsKey, NSMetadataUbiquitousSharedItemRoleOwner,
                        NSMetadataUbiquitousSharedItemRoleParticipant, NSMetadataUbiquitousSharedItemPermissionsReadOnly, NSMetadataUbiquitousSharedItemPermissionsReadWrite, NSExtensionHostDidBecomeActiveNotification,
                        NSExtensionHostDidEnterBackgroundNotification, NSExtensionHostWillEnterForegroundNotification, NSExtensionHostWillResignActiveNotification];
    for (NSUInteger index = 0; index < names.count; index++)
        record([@"constant." stringByAppendingString:names[index]], values[index]);

    vm_address_t vm = 0;
    vm_allocate(mach_task_self(), &vm, 4096, VM_FLAGS_ANYWHERE);
    NSDataDeallocatorVM((void *)vm, 4096);
    void *mapped = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    NSDataDeallocatorUnmap(mapped, 4096);
    NSDataDeallocatorFree(malloc(16), 16);
    record(@"deallocator.blocks", [NSString stringWithFormat:@"ran none=%d", NSDataDeallocatorNone == nil]);
    void *bytes = malloc(32);
    memset(bytes, 7, 32);
    NSData *data = [[NSData alloc] initWithBytesNoCopy:bytes length:32 deallocator:NSDataDeallocatorFree];
    record(@"deallocator.data", [NSString stringWithFormat:@"%lu %d", (unsigned long)data.length, ((const uint8_t *)data.bytes)[31]]);
    record(@"extension.main", [NSString stringWithFormat:@"%d", (void *)NSExtensionMain != NULL]);

    NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-intents"];
    [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    NSURL *file = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"one.txt"]];
    NSURL *other = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"two.txt"]];
    [@"one" writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSFileAccessIntent *reading = [NSFileAccessIntent readingIntentWithURL:file options:0];
    NSFileAccessIntent *writing = [NSFileAccessIntent writingIntentWithURL:other options:NSFileCoordinatorWritingForReplacing];
    record(@"intent.new", [NSString stringWithFormat:@"%@ %@ %d", reading.URL.lastPathComponent, writing.URL.lastPathComponent, [reading respondsToSelector:@selector(copyWithZone:)]]);
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    record(@"coordinate.read", wait_result(^NSString *(void (^done)(NSString *)) {
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        [coordinator coordinateAccessWithIntents:@[reading] queue:queue byAccessor:^(NSError *error) {
            NSString *text = [NSString stringWithContentsOfURL:reading.URL encoding:NSUTF8StringEncoding error:NULL];
            done([NSString stringWithFormat:@"error=%d text=%@ onQueue=%d name=%@", error != nil, text, [NSOperationQueue currentQueue] == queue, reading.URL.lastPathComponent]);
        }];
        return nil;
    }));
    record(@"coordinate.both", wait_result(^NSString *(void (^done)(NSString *)) {
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        [coordinator coordinateAccessWithIntents:@[reading, writing] queue:queue byAccessor:^(NSError *error) {
            NSError *failure = nil;
            BOOL wrote = [@"two" writeToURL:writing.URL atomically:YES encoding:NSUTF8StringEncoding error:&failure];
            done([NSString stringWithFormat:@"error=%d wrote=%d read=%@", error != nil, wrote, [NSString stringWithContentsOfURL:reading.URL encoding:NSUTF8StringEncoding error:NULL]]);
        }];
        return nil;
    }));
    record(@"coordinate.result", [NSString stringWithContentsOfURL:other encoding:NSUTF8StringEncoding error:NULL] ?: @"nil");
    record(@"coordinate.empty", wait_result(^NSString *(void (^done)(NSString *)) {
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        [coordinator coordinateAccessWithIntents:@[] queue:queue byAccessor:^(NSError *error) {
            done([NSString stringWithFormat:@"error=%d", error != nil]);
        }];
        return nil;
    }));
    NSURL *missing = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"missing/none.txt"]];
    NSFileAccessIntent *absent = [NSFileAccessIntent readingIntentWithURL:missing options:0];
    record(@"coordinate.missing", wait_result(^NSString *(void (^done)(NSString *)) {
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        [coordinator coordinateAccessWithIntents:@[absent] queue:queue byAccessor:^(NSError *error) {
            done([NSString stringWithFormat:@"error=%d read=%d", error != nil, [NSString stringWithContentsOfURL:absent.URL encoding:NSUTF8StringEncoding error:NULL] != nil]);
        }];
        return nil;
    }));
    record(@"coordinate.order", wait_result(^NSString *(void (^done)(NSString *)) {
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        __block NSInteger sequence = 0;
        NSArray *orders = @[@0, @0];
        [coordinator coordinateAccessWithIntents:@[reading, writing] queue:queue byAccessor:^(NSError *error) {
            sequence++;
            done([NSString stringWithFormat:@"%ld %lu", (long)sequence, (unsigned long)orders.count]);
        }];
        return nil;
    }));
    [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
}
