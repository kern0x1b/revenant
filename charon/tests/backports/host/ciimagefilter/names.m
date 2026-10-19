// The host's own answer to one thing: for every zero-argument class method of CIFilter, which filter it
// gives. Read from the runtime, so nothing here is transcribed, and printed as
//
//     <selector> TAB <filter name> TAB <input keys, comma-joined>
//
// which is the table spec/CoreImage/filter-builders.tsv that tools/gen/filter_builders.lua writes the port's constructors from. The
// names are the measurement; a naming convention would have been wrong for several of them, which is the
// point of reading them out instead of deriving them.
//
// Build and run:
//     xcrun clang -fobjc-arc names.m -framework Foundation -framework CoreImage -o names && ./names
#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <objc/runtime.h>
#import <objc/message.h>

typedef id (*CharonMsgSend0)(id, SEL);

int main(void)
{
    Class metaclass = object_getClass([CIFilter class]);
    unsigned count = 0;
    Method *methods = class_copyMethodList(metaclass, &count);
    NSMutableArray *lines = [NSMutableArray array];
    for (unsigned i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        const char *types = method_getTypeEncoding(methods[i]);
        const char *keyword = sel_getName(sel);
        if (!types || types[0] != '@') continue;
        if (strchr(keyword, ':')) continue;  // a method that takes nothing
        CIFilter *filter = ((CharonMsgSend0)objc_msgSend)((id)[CIFilter class], sel);
        if (![filter isKindOfClass:[CIFilter class]]) continue;
        [lines addObject:[NSString stringWithFormat:@"%s\t%@\t%@", keyword, filter.name,
                          [filter.inputKeys componentsJoinedByString:@","]]];
    }
    free(methods);
    [lines sortUsingSelector:@selector(compare:)];
    for (NSString *line in lines) printf("%s\n", line.UTF8String);
    fprintf(stderr, "class methods measured: %lu\n", (unsigned long)lines.count);
    return 0;
}