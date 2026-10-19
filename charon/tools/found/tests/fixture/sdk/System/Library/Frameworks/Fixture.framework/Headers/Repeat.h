// Repeats declarations of Fixture.h with other parameter names: the extractor emits the first one only.
//! Counts the items.
typedef int FXCount;
/** Runs the total.
 *  The total is added to the sum. */
void FXRun(int total);
void FXVersioned(void) __attribute__((availability(ios, introduced=17.0)));
/// Doubles a value.
int FXDouble(int value);
#define FX_TYPE_AVAILABLE __attribute__((availability(ios, introduced=16.0)))
typedef const struct FXString *FXStringRef;
extern const FXStringRef __nonnull FXConstName;
extern const char *const FXConstPointer;
extern char *const FXPointerConst;
extern const char *FXPointerToConst;
extern const int FXConstInt;
extern FX_TYPE_AVAILABLE const FXStringRef FXMacroConst;
extern FX_TYPE_AVAILABLE char *const FXMacroPointer;
#define FX_REFINED_FOR_SWIFT __attribute__((swift_private))
extern const FXStringRef FX_REFINED_FOR_SWIFT __nonnull FXRefinedName;
// the macro words of the declared types (the rule of 2026-10-10): a macro in front of a result, a parameter, a property or a typedef's
// underlying type is not part of that type
typedef FX_TYPE_AVAILABLE FXStringRef FXStringAlias;
FX_TYPE_AVAILABLE FXStringRef FXFetch(FX_TYPE_AVAILABLE const char *key);
@interface FXMacroBox
@property (nonatomic) FX_TYPE_AVAILABLE const FXStringRef macroProperty;
- (FX_TYPE_AVAILABLE FXStringRef)macroReturn;
- (void)macroTake:(FX_TYPE_AVAILABLE const char *)value;
@end
typedef FX_TYPE_AVAILABLE id _Nullable (^FXBlock)(FX_TYPE_AVAILABLE int value);
/*! Halves a value. */
int FXHalve(int value);
// the most platform records clang reports for one declaration (review F24): seventeen availability attributes give fourteen records, since
// visionos is xros and swift is no record; one record per platform
int FXManyPlatforms(void) __attribute__((availability(ios, introduced=1.0))) __attribute__((availability(macos, introduced=1.0))) __attribute__((availability(tvos, introduced=1.0))) __attribute__((availability(watchos, introduced=1.0))) __attribute__((availability(visionos, introduced=1.0))) __attribute__((availability(xros, introduced=1.0))) __attribute__((availability(maccatalyst, introduced=1.0))) __attribute__((availability(driverkit, introduced=1.0))) __attribute__((availability(bridgeos, introduced=1.0))) __attribute__((availability(ios_app_extension, introduced=1.0))) __attribute__((availability(macos_app_extension, introduced=1.0))) __attribute__((availability(tvos_app_extension, introduced=1.0))) __attribute__((availability(watchos_app_extension, introduced=1.0))) __attribute__((availability(visionos_app_extension, introduced=1.0))) __attribute__((availability(xros_app_extension, introduced=1.0))) __attribute__((availability(maccatalyst_app_extension, introduced=1.0))) __attribute__((availability(swift, introduced=1.0)));
