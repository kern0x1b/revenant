#import <Foundation/Foundation.h>
#include <objc/message.h>
#include <stdio.h>
#include <string.h>

typedef void (*VoidObject)(id, SEL, id);
typedef void (*VoidObjectIndex)(id, SEL, id, NSUInteger);
typedef void (*VoidObjectBlock)(id, SEL, id, void (^)(id, BOOL *));
typedef id (*ObjectWithObject)(id, SEL, id);
typedef void (*VoidCGFloat)(id, SEL, CGFloat);
typedef void (*VoidPoint)(id, SEL, CGPoint);

static SEL S(const char *name)
{
    return sel_registerName(name);
}

static NSString *describe(id object)
{
    if (object == nil) {
        return @"nil";
    }
    return [NSString stringWithFormat:@"%@", NSStringFromClass([object class])];
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    if (argc < 2) {
        fprintf(stderr, "usage: crash <case>\n");
        return 2;
    }
    NSString *caseName = [NSString stringWithUTF8String:argv[1]];
    Class nodeClass = NSClassFromString(@"SKNode");
    id root = [[nodeClass alloc] init];
    id child = [[nodeClass alloc] init];
    ((VoidObject)objc_msgSend)(root, S("addChild:"), child);

    @try {
        if ([caseName isEqualToString:@"childNodeWithName-nil"]) {
            printf("case=%s returned %s\n", argv[1], [describe(((ObjectWithObject)objc_msgSend)(root, S("childNodeWithName:"), nil)) UTF8String]);
        } else if ([caseName isEqualToString:@"childNodeWithName-empty"]) {
            printf("case=%s returned %s\n", argv[1], [describe(((ObjectWithObject)objc_msgSend)(root, S("childNodeWithName:"), @"")) UTF8String]);
        } else if ([caseName isEqualToString:@"subscript-nil"]) {
            printf("case=%s returned %s\n", argv[1], [describe(((ObjectWithObject)objc_msgSend)(root, S("objectForKeyedSubscript:"), nil)) UTF8String]);
        } else if ([caseName isEqualToString:@"subscript-empty"]) {
            printf("case=%s returned %s\n", argv[1], [describe(((ObjectWithObject)objc_msgSend)(root, S("objectForKeyedSubscript:"), @"")) UTF8String]);
        } else if ([caseName isEqualToString:@"enumerate-nil"]) {
            ((VoidObjectBlock)objc_msgSend)(root, S("enumerateChildNodesWithName:usingBlock:"), nil, ^(id node, BOOL *stop) {
                (void)node;
                (void)stop;
            });
            printf("case=%s returned\n", argv[1]);
        } else if ([caseName isEqualToString:@"insert-nil"]) {
            ((VoidObjectIndex)objc_msgSend)(root, S("insertChild:atIndex:"), nil, 0);
            printf("case=%s returned\n", argv[1]);
        } else if ([caseName isEqualToString:@"insert-at-count"]) {
            ((VoidObjectIndex)objc_msgSend)(root, S("insertChild:atIndex:"), [[nodeClass alloc] init], 1);
            printf("case=%s returned children=%lu\n", argv[1], (unsigned long)[((id (*)(id, SEL))objc_msgSend)(root, S("children")) count]);
        } else if ([caseName isEqualToString:@"insert-past-end"]) {
            ((VoidObjectIndex)objc_msgSend)(root, S("insertChild:atIndex:"), [[nodeClass alloc] init], 2);
            printf("case=%s returned children=%lu\n", argv[1], (unsigned long)[((id (*)(id, SEL))objc_msgSend)(root, S("children")) count]);
        } else if ([caseName isEqualToString:@"insert-huge"]) {
            ((VoidObjectIndex)objc_msgSend)(root, S("insertChild:atIndex:"), [[nodeClass alloc] init], NSUIntegerMax);
            printf("case=%s returned children=%lu\n", argv[1], (unsigned long)[((id (*)(id, SEL))objc_msgSend)(root, S("children")) count]);
        } else if ([caseName hasPrefix:@"insert-index-"]) {
            NSUInteger index = (NSUInteger)strtoull(argv[1] + strlen("insert-index-"), NULL, 10);
            ((VoidObjectIndex)objc_msgSend)(root, S("insertChild:atIndex:"), [[nodeClass alloc] init], index);
            printf("case=%s returned children=%lu\n", argv[1], (unsigned long)[((id (*)(id, SEL))objc_msgSend)(root, S("children")) count]);
        } else if ([caseName isEqualToString:@"insert-nil-described"]) {
            ((VoidObject)objc_msgSend)(root, S("setName:"), @"root");
            ((VoidPoint)objc_msgSend)(root, S("setPosition:"), CGPointMake(3, 4));
            ((VoidCGFloat)objc_msgSend)(root, S("setXScale:"), 2);
            ((VoidCGFloat)objc_msgSend)(root, S("setYScale:"), 0.5);
            ((VoidObjectIndex)objc_msgSend)(root, S("insertChild:atIndex:"), nil, 0);
            printf("case=%s returned\n", argv[1]);
        } else {
            fprintf(stderr, "unknown case %s\n", argv[1]);
            return 2;
        }
    } @catch (NSException *exception) {
        printf("case=%s exception name=%s reason=%s\n", argv[1], [exception.name UTF8String],
               exception.reason != nil ? [exception.reason UTF8String] : "(nil)");
    }
    return 0;
}
