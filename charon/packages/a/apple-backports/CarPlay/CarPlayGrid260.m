// CarPlayGrid260.m - the 26.0 members of CPGridButton and CPListTemplate, in a 26.0 object of their own.
//
// CPGridButton.h:60-63 declares the designated initialiser with a message configuration and :71 the
// `messageConfiguration` property and :86-87 `updateTitleVariants:`; CPListTemplate.h the 26.0
// initialiser with header grid buttons and :265 `headerGridButtons`. All are `API_AVAILABLE(ios(26.0))`
// and none is in the build SDK, which is 16.4 - the one type they need that the build SDK does not
// declare, CPMessageGridItemConfiguration, is declared in CharonCarPlay260.h for that reason.
//
// THE THREE CLASS PROPERTIES ARE NOT HERE, and their registry rows say why: each answers a number the
// system owns for a car screen, and this port has no car. CPGridTemplate.h:34-38 calls the image size
// "The expected image size for your CPGridButton" and points at -[CPInterfaceController
// carTraitCollection] for the scale; CPListTemplate.h:246-251 says a template "will display the first
// maximumHeaderGridButtonCount buttons" and that "Any sections beyond that limit will be trimmed". A
// number this port chose would be a limit Apple's car screens do not have, which is the absence the rest
// of CarPlay's drawing half already answers for: there is no scene, no CPWindow connection and no head
// unit, and this release's own 12.0 object is a UITableViewController that nothing shows.
//
// The storage of both classes' new members is the classes' own, in CarPlayTemplates12.m and
// CarPlayTemplatesView12.m, reached through the charon_ accessors of CharonCarPlayTemplate.h - the same
// shape CarPlayNavigationSession154.m uses for _turnCardColor. A category cannot add an ivar.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CarPlay/CarPlay.h>
#import "CharonCarPlay260.h"
#import "CharonCarPlayTemplate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CPMessageGridItemConfiguration {
    NSString *_conversationIdentifier;
    BOOL _unread;
}

@synthesize conversationIdentifier = _conversationIdentifier;

- (instancetype)initWithConversationIdentifier:(NSString *)conversationIdentifier
                                        unread:(BOOL)unread
{
    // CPGridButton.h:20-26 is the header's own account: the identifier "is not directly displayed to the
    // user" and is what SiriKit hands back when the item is selected, and unread says whether the item
    // shows an unread indicator. Both are kept as given, and the identifier is copied, which is the
    // header's own `copy` on the property at :32.
    self = [super init];
    if (self) {
        _conversationIdentifier = [conversationIdentifier copy] ?: @"";
        _unread = unread;
    }
    return self;
}

- (BOOL)isUnread { return _unread; }

- (void)setUnread:(BOOL)unread { _unread = unread; }

@end

@implementation CPListTemplate (CharonGrid260)

// CPListTemplate.h:255-265: assigning to this property updates the List Template at once and shows
// the new header. The value is kept and copied, per the header's own `nullable, copy`, and a nil in is a
// nil out. What a caller can observe is the array: this release's list template is a UITableViewController
// that no head unit shows, and a CPGridButton is not a CPBarButton, so there is no bar of this port's own
// that these buttons would go into - which is what the row's effect says as well.
- (NSArray<CPGridButton *> *)headerGridButtons
{
    return [self charon_headerGridButtons];
}

- (void)setHeaderGridButtons:(NSArray<CPGridButton *> *)headerGridButtons
{
    [self charon_setHeaderGridButtons:headerGridButtons];
}

// The 26.0 initialiser: the 15.0 one with header grid buttons beside it. The 15.0 half is
// CarPlayTemplates150.m's, so this reaches it rather than filling the same fields twice.
- (instancetype)initWithTitle:(NSString *)title
                     sections:(NSArray<CPListSection *> *)sections
   assistantCellConfiguration:(CPAssistantCellConfiguration *)assistantCellConfiguration
            headerGridButtons:(NSArray<CPGridButton *> *)headerGridButtons
{
    self = [self initWithTitle:title
                     sections:sections
   assistantCellConfiguration:assistantCellConfiguration];
    if (self) {
        [self charon_setHeaderGridButtons:headerGridButtons];
    }
    return self;
}

@end

@implementation CPGridButton (CharonGrid260)

// CPGridButton.h:60-63, the designated initialiser. The 12.0 one at :55 takes the same four values minus
// the configuration, so this goes through it and then stores the configuration. A nil configuration is a
// nil out, which is what the header's `nullable` on the argument means and what the `nullable` on the
// property at :71 promises.
- (instancetype)initWithTitleVariants:(NSArray<NSString *> *)titleVariants
                                image:(UIImage *)image
                 messageConfiguration:(CPMessageGridItemConfiguration *)messageConfiguration
                              handler:(void (^)(CPGridButton *))handler
{
    self = [self initWithTitleVariants:titleVariants image:image handler:handler];
    if (self) {
        [self charon_setMessageConfiguration:messageConfiguration];
    }
    return self;
}

// CPGridButton.h:71, `readonly, nullable`: what the initialiser was given, and nil when none was.
- (CPMessageGridItemConfiguration *)messageConfiguration
{
    return [self charon_messageConfiguration];
}

// CPGridButton.h:86-87. The header says that the system selects a title from the list of variants supplied,
// fitting the available space, and the selection is the system's: what this answers is the list the
// caller gave, copied, and the variant this port draws is still the first, which is the rule the 12.0
// object's own -charon_drawInRect: already uses.
- (void)updateTitleVariants:(NSArray<NSString *> *)titleVariants
{
    [self charon_setTitleVariants:titleVariants];
}

// CPGridButton.h:86 declares `image` readonly and :87 `-updateImage:` as its only writer, API_AVAILABLE
// (ios(26.0)), so it is in this object and not in the 12.0 one that defines the class. What it says is
// the whole of it: "Updates the image displayed by the grid button." The button draws itself - every
// grid button in this port goes through the class's own -charon_drawInRect:, which reads the image -
// so this changes what the class draws and needs no drawing of its own.
- (void)updateImage:(UIImage *)image
{
    // Kept as given, nil included: a grid button with no image is the empty state the class's own
    // drawing already draws, and a substituted picture would be something the caller did not ask for.
    [self charon_setImage:image];
}

@end

NS_ASSUME_NONNULL_END