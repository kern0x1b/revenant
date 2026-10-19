#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>

typedef NS_ENUM(NSInteger, PSCellType) {
    PSGroupCell = 0,
    PSLinkCell,
    PSLinkListCell,
    PSListItemCell,
    PSTitleValueCell,
    PSSliderCell,
    PSSwitchCell,
    PSStaticTextCell,
    PSEditTextCell,
    PSButtonCell,
    PSSecureEditTextCell,
};

@interface PSSpecifier : NSObject
+ (PSSpecifier *)preferenceSpecifierNamed:(NSString *)name
                                   target:(id)target
                                      set:(SEL)set
                                      get:(SEL)get
                                   detail:(Class)detail
                                     cell:(PSCellType)cell
                                     edit:(Class)edit;
+ (PSSpecifier *)groupSpecifierWithName:(NSString *)name;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
- (void)setButtonAction:(SEL)action;
- (void)setTarget:(id)target;
@property (nonatomic, retain) NSString *identifier;
@end

@interface PSViewController : UIViewController
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)spec;
- (id)readPreferenceValue:(PSSpecifier *)spec;
@end

@interface PSListController : PSViewController {
    NSArray *_specifiers;
}
- (NSArray *)specifiers;
- (void)reloadSpecifiers;
- (NSMutableArray *)loadSpecifiersFromPlistName:(NSString *)plist target:(id)target;
@end
