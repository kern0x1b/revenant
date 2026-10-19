// Fixture: one declaration of each kind the extractor emits, and the branches it must choose.
#import "Sub.h"
#import "Repeat.h"
#import <fixture_types.h>

typedef int FXCount;
extern const double FXScale;
struct FXPoint { double x; double y; };
typedef struct FXOpaque FXOpaque;
enum FXState;
enum FXState { FXStateOn = 1, FXStateOff = 2 };
enum { FXLimit = 9 };
// the value of an enum constant is clang's own for the enum's integer type: an unsigned enum is not sign-extended
enum FXByte : unsigned char { FXByteTop = 255 };
enum FXWord : unsigned long { FXWordAll = ~0UL };
enum FXWide : unsigned long long { FXWideTop = 1ULL << 63 };
enum FXMask { FXMaskClass = 15U << 28 };
enum FXSigned : int { FXSignedBelow = -1 };
void FXRun(int count);
void FXMove(fx_vector3 at, fx_family family);

#define FX_NO_INIT - (instancetype)init __attribute__((unavailable))

#ifdef __arm64__
@protocol FXSource
@optional
- (nullable id)valueForKey:(nullable id)key;
@end

@interface FXWidget
@property (nonatomic, readonly, getter=isEnabledNow) _Bool enabled;
@property (class, nonatomic, copy, nullable) id label;
+ (instancetype)widgetNamed:(nullable id)name __attribute__((availability(ios, introduced=16.0)));
FX_NO_INIT;
@end

@interface FXWidget () <FXSource>
@end

@interface FXWidget (Extras)
- (void)extraAction;
@end

__attribute__((availability(ios, introduced=14.0))) @interface FXLegacy
- (void)old;
- (void)tweak;
@end

@interface FXLegacy ()
- (void)old __attribute__((availability(ios, introduced=16.0)));
- (void)tweak __attribute__((availability(ios, introduced=12.0)));
@end
#endif

@protocol FXLater;
void FXVersioned(void) __attribute__((availability(ios, introduced=15.0)));

#ifdef __x86_64__
@interface FXOnlyIntel
- (void)neverEmitted;
@end
#endif
