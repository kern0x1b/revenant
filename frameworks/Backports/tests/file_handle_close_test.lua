local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local category = path.join(backports, "src", "Foundation", "NSFileHandle+Errors13.m")

local MAIN = [[
#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <unistd.h>

@interface StaleHandle : NSFileHandle
{
    int stored;
}
- (instancetype)initWithDescriptor:(int)descriptor;
@end

@implementation StaleHandle
- (instancetype)initWithDescriptor:(int)descriptor
{
    self = [super init];
    stored = descriptor;
    return self;
}
- (int)fileDescriptor
{
    return stored;
}
@end

int main(int argc, const char **argv)
{
    @autoreleasepool {
        const char *path = argv[1];
        NSString *folder = [NSString stringWithUTF8String:path];
        NSString *first = [folder stringByAppendingPathComponent:@"first.bin"];
        NSString *second = [folder stringByAppendingPathComponent:@"second.bin"];
        NSFileManager *manager = [NSFileManager defaultManager];
        [manager createFileAtPath:first contents:[@"first" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
        [manager createFileAtPath:second contents:[@"second" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
        int descriptor = open(first.fileSystemRepresentation, O_RDONLY);
        StaleHandle *handle = [[StaleHandle alloc] initWithDescriptor:descriptor];
        [handle closeFile];
        int reused = open(second.fileSystemRepresentation, O_RDONLY);
        NSError *error = nil;
        NSData *data = [handle readDataUpToLength:64 error:&error];
        printf("number reused: %s\n", reused == descriptor ? "yes" : "no");
        printf("read after close: %s\n", data == nil && error != nil ? "error" : "data");
        close(reused);
        [manager removeItemAtPath:first error:NULL];
        [manager removeItemAtPath:second error:NULL];
    }
    return 0;
}
]]

function main()
    local out = workspace.run("backports-tests", "FileHandleClose")
    local source = path.join(out, "main.m")
    io.writefile(source, MAIN)
    local probe = path.join(out, "probe")
    os.vrunv("xcrun", {"clang", "-fobjc-arc", "-framework", "Foundation", source, category, "-o", probe})
    local log = path.join(out, "probe.log")
    local status = os.execv(probe, {out}, {try = true, stdout = log, stderr = log})
    assert(status == 0, "the FileHandle close probe did not run: " .. io.readfile(log))
    local text = io.readfile(log)
    assert(text:find("number reused: yes", 1, true), "the probe did not reuse the closed descriptor number: " .. text)
    assert(text:find("read after close: error", 1, true), "closeFile did not mark the handle closed: " .. text)
end
