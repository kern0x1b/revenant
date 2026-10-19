#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlayTemplate.h"

@implementation CPListSection (CharonCarPlay150)

- (instancetype)initWithItems:(NSArray<id<CPListTemplateItem>> *)items
                       header:(NSString *)header
               headerSubtitle:(NSString *)headerSubtitle
                  headerImage:(UIImage *)headerImage
                 headerButton:(CPButton *)headerButton
            sectionIndexTitle:(NSString *)sectionIndexTitle
{
    self = [self initWithItems:items header:header sectionIndexTitle:sectionIndexTitle];
    if (self) {
        [self charon_setHeaderSubtitle:headerSubtitle];
        [self charon_setHeaderImage:headerImage];
        [self charon_setHeaderButton:headerButton];
    }
    return self;
}

@end

@implementation CPListTemplate (CharonCarPlay150)

- (instancetype)initWithTitle:(NSString *)title
                     sections:(NSArray<CPListSection *> *)sections
   assistantCellConfiguration:(CPAssistantCellConfiguration *)assistantCellConfiguration
{
    self = [self initWithTitle:title sections:sections];
    if (self) {
        self.assistantCellConfiguration = assistantCellConfiguration;
    }
    return self;
}

@end
