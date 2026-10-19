#import <Foundation/Foundation.h>

@implementation NSDateFormatter (CharonLocalizedTemplate)

- (void)setLocalizedDateFormatFromTemplate:(NSString *)dateFormatTemplate
{
    self.dateFormat = [NSDateFormatter dateFormatFromTemplate:dateFormatTemplate options:0 locale:self.locale];
}

@end
