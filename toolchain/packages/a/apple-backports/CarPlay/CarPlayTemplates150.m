#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "RevenantCarPlayTemplate.h"

@implementation CPListSection (RevenantCarPlay150)

- (instancetype)initWithItems:(NSArray<id<CPListTemplateItem>> *)items
                       header:(NSString *)header
               headerSubtitle:(NSString *)headerSubtitle
                  headerImage:(UIImage *)headerImage
                 headerButton:(CPButton *)headerButton
            sectionIndexTitle:(NSString *)sectionIndexTitle
{
    self = [self initWithItems:items header:header sectionIndexTitle:sectionIndexTitle];
    if (self) {
        [self revenant_setHeaderSubtitle:headerSubtitle];
        [self revenant_setHeaderImage:headerImage];
        [self revenant_setHeaderButton:headerButton];
    }
    return self;
}

@end

@implementation CPListTemplate (RevenantCarPlay150)

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
