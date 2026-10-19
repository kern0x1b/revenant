// CarPlayTemplates150.m - the 15.0 members of the list template and its sections, in an object of their
// own beside the 12.0 one that defines the classes.
//
// CPListSection.h:60 and CPListTemplate.h:102 are the two declarations, and both are `API_AVAILABLE
// (ios(15.0))` in the header the build already compiles against (iPhoneOS16.4's CarPlay.framework). The
// classes themselves are 12.0 and their @implementation is CarPlayTemplatesView12.m, so an object may
// hold API of exactly one release (modules/apple/backports.lua's releases_in, read by
// tools/release-split.lua) and these two are the 15.0 half of two classes whose other half is 12.0 -
// the same split CarPlayLane174.m and CarPlayLane18.m make for CPLane.
//
// Nothing needs a seam. CPListSection.h:82-97 declares header, headerSubtitle, headerImage, headerButton
// and sectionIndexTitle, and the header's own -updateItems:header:headerSubtitle:headerImage:
// sectionIndexTitle:headerButton: fills all five, which CarPlayTemplatesView12.m already implements; and
// CPListTemplate.h:97 declares assistantCellConfiguration, which the 12.0 object already synthesises.

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
    // The header's own 12.0 initialiser with the three values it takes, then the other five through the
    // class's own storage, in the order CPListSection.h:60 gives them. `nil` for a header is what the
    // header means by the `nullable` it writes on the two images and on the button, and the strings are
    // copied by the setters, so a later change to the caller's strings does not change the section.
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
    // CPListTemplate.h:94-102 says the assistant cell is the 12.0 initialiser plus a configuration, and
    // the note above it that only CarPlay Audio and Communication Apps are supported - which is what
    // this object is: the configuration is kept and answered, and it is the template's own property
    // (CPListTemplate.h:110) that a caller reads back. The nil in stays nil, because the declaration
    // says `nullable` and an assistant cell with no configuration is an ordinary state.
    self = [self initWithTitle:title sections:sections];
    if (self) {
        self.assistantCellConfiguration = assistantCellConfiguration;
    }
    return self;
}

@end