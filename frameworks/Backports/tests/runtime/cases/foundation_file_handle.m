#import "../app/revenant_check.h"

REVENANT_CASE(foundation_file_handle)
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *folder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *path = [folder stringByAppendingPathComponent:@"revenant-file-handle-case.bin"];
    [manager removeItemAtPath:path error:NULL];
    [manager createFileAtPath:path contents:nil attributes:nil];

    NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:path];
    NSError *error = nil;
    NSData *payload = [@"hello world" dataUsingEncoding:NSUTF8StringEncoding];
    BOOL written = [handle writeData:payload error:&error];
    revenant_expect_true(@"the refined write succeeds", written && error == nil, [error description]);

    unsigned long long position = 0;
    BOOL gotOffset = [handle getOffset:&position error:&error];
    revenant_expect_integer(@"the refined offset follows the write", gotOffset ? (long long)position : -1, (long long)payload.length);

    unsigned long long end = 0;
    BOOL gotEnd = [handle seekToEndReturningOffset:&end error:&error];
    revenant_expect_integer(@"the refined end offset is the file length", gotEnd ? (long long)end : -1, (long long)payload.length);

    BOOL rewound = [handle seekToOffset:0 error:&error];
    revenant_expect_true(@"the refined seek succeeds", rewound, [error description]);

    NSData *first = [handle readDataUpToLength:5 error:&error];
    NSString *expected = negative ? @"hellX" : @"hello";
    revenant_expect_string(@"the refined read returns the requested bytes", first ? [[NSString alloc] initWithData:first encoding:NSUTF8StringEncoding] : nil, expected);

    NSData *rest = [handle readDataUpToLength:100 error:&error];
    revenant_expect_string(@"the refined read stops at the end of the file", rest ? [[NSString alloc] initWithData:rest encoding:NSUTF8StringEncoding] : nil, @" world");

    NSData *empty = [handle readDataUpToLength:1 error:&error];
    revenant_expect_integer(@"the refined read at the end is empty for Swift to map to nil", empty ? (long long)empty.length : -1, 0);

    BOOL truncated = [handle truncateAtOffset:5 error:&error];
    revenant_expect_true(@"the refined truncate succeeds", truncated, [error description]);
    end = 0;
    gotEnd = [handle seekToEndReturningOffset:&end error:&error];
    revenant_expect_integer(@"the end offset follows the truncate", gotEnd ? (long long)end : -1, 5);

    BOOL synchronized = [handle synchronizeAndReturnError:&error];
    revenant_expect_true(@"the refined synchronize succeeds", synchronized, [error description]);

    BOOL closed = [handle closeAndReturnError:&error];
    revenant_expect_true(@"the refined close succeeds", closed, [error description]);

    error = nil;
    NSData *afterClose = [handle readDataUpToLength:1 error:&error];
    revenant_expect_true(@"a read after close fails with an error instead of an exception", afterClose == nil && error != nil, [error description]);

    error = nil;
    BOOL wroteAfterClose = [handle writeData:payload error:&error];
    revenant_expect_true(@"a write after close fails with an error instead of an exception", !wroteAfterClose && error != nil, [error description]);

    [manager removeItemAtPath:path error:NULL];

    NSString *first = [folder stringByAppendingPathComponent:@"revenant-file-handle-close-a.bin"];
    NSString *second = [folder stringByAppendingPathComponent:@"revenant-file-handle-close-b.bin"];
    [manager removeItemAtPath:first error:NULL];
    [manager removeItemAtPath:second error:NULL];
    [manager createFileAtPath:first contents:[@"first" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    [manager createFileAtPath:second contents:[@"second" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];

    NSFileHandle *closed = [NSFileHandle fileHandleForReadingAtPath:first];
    [closed closeFile];
    NSFileHandle *reused = [NSFileHandle fileHandleForReadingAtPath:second];
    error = nil;
    NSData *afterInheritedClose = [closed readDataUpToLength:64 error:&error];
    revenant_expect_true(@"a handle closed by closeFile fails a later read even when its number is reused",
                         afterInheritedClose == nil && error != nil, [error description]);
    [reused closeFile];
    [manager removeItemAtPath:first error:NULL];
    [manager removeItemAtPath:second error:NULL];
}
