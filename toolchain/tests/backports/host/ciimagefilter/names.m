#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <objc/runtime.h>
#import <objc/message.h>

typedef id (*RevenantMsgSend0)(id, SEL);

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
        if (strchr(keyword, ':')) continue;
        CIFilter *filter = ((RevenantMsgSend0)objc_msgSend)((id)[CIFilter class], sel);
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
