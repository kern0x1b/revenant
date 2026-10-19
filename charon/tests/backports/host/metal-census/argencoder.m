#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static int failures;

static void check(BOOL ok, NSString *what)
{
    if (ok) { printf("  ok   %s\n", [what UTF8String]); }
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

int main(void)
{
    @autoreleasepool {
        NSArray *vended = @[ @"CharonMetalBinding", @"CharonMetalBufferBinding",
                              @"CharonMetalTextureBinding", @"CharonMetalThreadgroupBinding",
                              @"CharonMetalObjectPayloadBinding" ];
        for (NSString *name in vended) {
            check(NSClassFromString(name) != nil,
                  ([NSString stringWithFormat:@"the port vends %@, and the runtime finds it", name]));
        }

        check(NSClassFromString(@"MTLArgumentEncoder") == nil,
              @"the port vends no MTLArgumentEncoder class, so a caller has no members to call");

        NSMutableArray *portClasses = [NSMutableArray array];
        int total = objc_getClassList(NULL, 0);
        Class *all = (Class *)malloc(sizeof(Class) * total);
        total = objc_getClassList(all, total);
        for (int i = 0; i < total; i++) {
            NSString *name = NSStringFromClass(all[i]);
            if ([name hasPrefix:@"CharonMetal"]) { [portClasses addObject:name]; }
        }
        free(all);
        NSArray *sorted = [portClasses sortedArrayUsingSelector:@selector(compare:)];
        NSArray *want = [vended sortedArrayUsingSelector:@selector(compare:)];
        check(sorted.count == 5 && [sorted isEqualToArray:want],
              ([NSString stringWithFormat:@"the port's whole class set here is its 5 bindings, and holds"
                                           @" no encoder: %@", [sorted componentsJoinedByString:@", "]]));
    }
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("all checks passed\n");
    return 0;
}
