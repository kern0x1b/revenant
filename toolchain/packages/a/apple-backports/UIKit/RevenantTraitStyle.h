#import <UIKit/UIKit.h>

UIUserInterfaceStyle revenant_trait_style(UITraitCollection *collection);
void revenant_set_trait_style(UITraitCollection *collection, UIUserInterfaceStyle style);

typedef void (*RevenantTraitChangeObserver)(NSArray *environments, NSArray *previous);
void revenant_add_trait_change_observer(RevenantTraitChangeObserver observer);
void revenant_call_trait_change_observers(NSArray *environments, NSArray *previous);

typedef struct {
    __unsafe_unretained NSString *name;
    NSInteger screenDefault;
    int described;
    __unsafe_unretained NSString *first;
    __unsafe_unretained NSString *second;
} RevenantTraitKind;

void revenant_register_trait_kind(RevenantTraitKind kind);
NSInteger revenant_trait_extra(UITraitCollection *collection, NSString *name);
void revenant_set_trait_extra(UITraitCollection *collection, NSString *name, NSInteger value);
NSDictionary *revenant_trait_extras(UITraitCollection *collection);
NSDictionary *revenant_merge_trait_extras(NSArray *collections);
void revenant_apply_trait_extras(UITraitCollection *collection, NSDictionary *extras);
void revenant_apply_screen_trait_extras(UITraitCollection *collection);
BOOL revenant_trait_extras_contained(UITraitCollection *collection, UITraitCollection *wanted);
BOOL revenant_trait_extras_equal(UITraitCollection *a, UITraitCollection *b);
NSUInteger revenant_trait_extras_hash(UITraitCollection *collection);
void revenant_add_trait_extras_description(UITraitCollection *collection, NSMutableArray *traits);
void revenant_encode_trait_extras(UITraitCollection *collection, NSCoder *coder);
void revenant_decode_trait_extras(UITraitCollection *collection, NSCoder *coder);

id revenant_trait_extra_object(UITraitCollection *collection, NSString *name);
void revenant_set_trait_extra_object(UITraitCollection *collection, NSString *name, id value);

void revenant_set_trait_force_touch(UITraitCollection *collection, UIForceTouchCapability capability);
void revenant_set_screen_trait_force_touch(UITraitCollection *collection);

void revenant_deliver_trait_registrations(NSArray *environments, NSArray *previous);
