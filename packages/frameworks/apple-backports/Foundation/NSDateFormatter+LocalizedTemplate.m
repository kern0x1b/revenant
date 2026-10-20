#import <Foundation/Foundation.h>

@implementation NSDateFormatter (RevenantLocalizedTemplate)

- (void)setLocalizedDateFormatFromTemplate:(NSString *)dateFormatTemplate
{
    self.dateFormat = [NSDateFormatter dateFormatFromTemplate:dateFormatTemplate options:0 locale:self.locale];
}

@end
