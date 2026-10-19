#import <Foundation/Foundation.h>

#define APPGROUP_IDENTIFIERS @[@"group.test.app", @"ABCDE12345.shared", @"", @"a", @"group.a/b", @"../x", @"group.with space", @"group.\u00e9", @"group.\u00fc\u00f1", @"group.\u65e5\u672c", @"GROUP.Mixed", @"group.a:b", @"group.a\\b", @"  ", @"group.e\u0301", @"group.a!b#c$d%e&f", @"g(1)[2]{3}", @"group.\U0001F600", @"a~b`c^d|e", @"UPPER lower_09.-"]

static NSString *appgroup_relative(NSURL *url, NSString *home)
{
    if (!url)
        return @"nil";
    NSString *path = url.path;
    if ([path hasPrefix:home])
        path = [path substringFromIndex:home.length];
    return [NSString stringWithFormat:@"%@ file %d dir-url %d", path, url.isFileURL, [url.absoluteString hasSuffix:@"/"]];
}
