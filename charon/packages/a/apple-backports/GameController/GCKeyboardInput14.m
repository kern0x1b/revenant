#import "CharonGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

// The keyboard profile: one button per key code, the same spec pipeline every other profile in
// this package is built from, so a key is a real GCControllerButtonInput that reads 0 and is not
// pressed until something sets it, and a caller can poll it or hook a handler on it.
//
// The table is the SDK's own GCKeyCodes.h list, one spec per key the port carries a value for,
// with the key's name as the alias - the form GCKeyNames.h uses and the form -buttonForKeyCode:
// and the profile's subscript both answer with. The eight keys that list carries and this port
// does not (GCKeyCodeF13 through GCKeyCodeF20, which are macOS-only) are named in the facts page
// as the difference in count between this profile and the host's, which has all 134.

@implementation GCKeyboardInput {
    GCKeyboardValueChangedHandler _keyChangedHandler;
    NSDictionary<NSNumber *, GCControllerButtonInput *> *_byKeyCode;
    BOOL _anyKeyPressed;
}

- (instancetype)init
{
    NSArray *specs = @[
        @{@"kind": @"button", @"aliases": @[@"A"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @0, @"keyCode": @(GCKeyCodeKeyA)},
        @{@"kind": @"button", @"aliases": @[@"B"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @1, @"keyCode": @(GCKeyCodeKeyB)},
        @{@"kind": @"button", @"aliases": @[@"C"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @2, @"keyCode": @(GCKeyCodeKeyC)},
        @{@"kind": @"button", @"aliases": @[@"D"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @3, @"keyCode": @(GCKeyCodeKeyD)},
        @{@"kind": @"button", @"aliases": @[@"E"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @4, @"keyCode": @(GCKeyCodeKeyE)},
        @{@"kind": @"button", @"aliases": @[@"F"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @5, @"keyCode": @(GCKeyCodeKeyF)},
        @{@"kind": @"button", @"aliases": @[@"G"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @6, @"keyCode": @(GCKeyCodeKeyG)},
        @{@"kind": @"button", @"aliases": @[@"H"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @7, @"keyCode": @(GCKeyCodeKeyH)},
        @{@"kind": @"button", @"aliases": @[@"I"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @8, @"keyCode": @(GCKeyCodeKeyI)},
        @{@"kind": @"button", @"aliases": @[@"J"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @9, @"keyCode": @(GCKeyCodeKeyJ)},
        @{@"kind": @"button", @"aliases": @[@"K"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @10, @"keyCode": @(GCKeyCodeKeyK)},
        @{@"kind": @"button", @"aliases": @[@"L"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @11, @"keyCode": @(GCKeyCodeKeyL)},
        @{@"kind": @"button", @"aliases": @[@"M"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @12, @"keyCode": @(GCKeyCodeKeyM)},
        @{@"kind": @"button", @"aliases": @[@"N"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @13, @"keyCode": @(GCKeyCodeKeyN)},
        @{@"kind": @"button", @"aliases": @[@"O"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @14, @"keyCode": @(GCKeyCodeKeyO)},
        @{@"kind": @"button", @"aliases": @[@"P"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @15, @"keyCode": @(GCKeyCodeKeyP)},
        @{@"kind": @"button", @"aliases": @[@"Q"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @16, @"keyCode": @(GCKeyCodeKeyQ)},
        @{@"kind": @"button", @"aliases": @[@"R"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @17, @"keyCode": @(GCKeyCodeKeyR)},
        @{@"kind": @"button", @"aliases": @[@"S"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @18, @"keyCode": @(GCKeyCodeKeyS)},
        @{@"kind": @"button", @"aliases": @[@"T"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @19, @"keyCode": @(GCKeyCodeKeyT)},
        @{@"kind": @"button", @"aliases": @[@"U"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @20, @"keyCode": @(GCKeyCodeKeyU)},
        @{@"kind": @"button", @"aliases": @[@"V"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @21, @"keyCode": @(GCKeyCodeKeyV)},
        @{@"kind": @"button", @"aliases": @[@"W"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @22, @"keyCode": @(GCKeyCodeKeyW)},
        @{@"kind": @"button", @"aliases": @[@"X"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @23, @"keyCode": @(GCKeyCodeKeyX)},
        @{@"kind": @"button", @"aliases": @[@"Y"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @24, @"keyCode": @(GCKeyCodeKeyY)},
        @{@"kind": @"button", @"aliases": @[@"Z"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @25, @"keyCode": @(GCKeyCodeKeyZ)},
        @{@"kind": @"button", @"aliases": @[@"One"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @26, @"keyCode": @(GCKeyCodeOne)},
        @{@"kind": @"button", @"aliases": @[@"Two"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @27, @"keyCode": @(GCKeyCodeTwo)},
        @{@"kind": @"button", @"aliases": @[@"Three"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @28, @"keyCode": @(GCKeyCodeThree)},
        @{@"kind": @"button", @"aliases": @[@"Four"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @29, @"keyCode": @(GCKeyCodeFour)},
        @{@"kind": @"button", @"aliases": @[@"Five"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @30, @"keyCode": @(GCKeyCodeFive)},
        @{@"kind": @"button", @"aliases": @[@"Six"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @31, @"keyCode": @(GCKeyCodeSix)},
        @{@"kind": @"button", @"aliases": @[@"Seven"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @32, @"keyCode": @(GCKeyCodeSeven)},
        @{@"kind": @"button", @"aliases": @[@"Eight"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @33, @"keyCode": @(GCKeyCodeEight)},
        @{@"kind": @"button", @"aliases": @[@"Nine"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @34, @"keyCode": @(GCKeyCodeNine)},
        @{@"kind": @"button", @"aliases": @[@"Zero"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @35, @"keyCode": @(GCKeyCodeZero)},
        @{@"kind": @"button", @"aliases": @[@"ReturnOrEnter"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @36, @"keyCode": @(GCKeyCodeReturnOrEnter)},
        @{@"kind": @"button", @"aliases": @[@"Escape"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @37, @"keyCode": @(GCKeyCodeEscape)},
        @{@"kind": @"button", @"aliases": @[@"DeleteOrBackspace"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @38, @"keyCode": @(GCKeyCodeDeleteOrBackspace)},
        @{@"kind": @"button", @"aliases": @[@"Tab"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @39, @"keyCode": @(GCKeyCodeTab)},
        @{@"kind": @"button", @"aliases": @[@"Spacebar"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @40, @"keyCode": @(GCKeyCodeSpacebar)},
        @{@"kind": @"button", @"aliases": @[@"Hyphen"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @41, @"keyCode": @(GCKeyCodeHyphen)},
        @{@"kind": @"button", @"aliases": @[@"EqualSign"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @42, @"keyCode": @(GCKeyCodeEqualSign)},
        @{@"kind": @"button", @"aliases": @[@"OpenBracket"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @43, @"keyCode": @(GCKeyCodeOpenBracket)},
        @{@"kind": @"button", @"aliases": @[@"CloseBracket"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @44, @"keyCode": @(GCKeyCodeCloseBracket)},
        @{@"kind": @"button", @"aliases": @[@"Backslash"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @45, @"keyCode": @(GCKeyCodeBackslash)},
        @{@"kind": @"button", @"aliases": @[@"NonUSPound"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @46, @"keyCode": @(GCKeyCodeNonUSPound)},
        @{@"kind": @"button", @"aliases": @[@"Semicolon"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @47, @"keyCode": @(GCKeyCodeSemicolon)},
        @{@"kind": @"button", @"aliases": @[@"Quote"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @48, @"keyCode": @(GCKeyCodeQuote)},
        @{@"kind": @"button", @"aliases": @[@"GraveAccentAndTilde"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @49, @"keyCode": @(GCKeyCodeGraveAccentAndTilde)},
        @{@"kind": @"button", @"aliases": @[@"Comma"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @50, @"keyCode": @(GCKeyCodeComma)},
        @{@"kind": @"button", @"aliases": @[@"Period"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @51, @"keyCode": @(GCKeyCodePeriod)},
        @{@"kind": @"button", @"aliases": @[@"Slash"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @52, @"keyCode": @(GCKeyCodeSlash)},
        @{@"kind": @"button", @"aliases": @[@"CapsLock"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @53, @"keyCode": @(GCKeyCodeCapsLock)},
        @{@"kind": @"button", @"aliases": @[@"F1"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @54, @"keyCode": @(GCKeyCodeF1)},
        @{@"kind": @"button", @"aliases": @[@"F2"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @55, @"keyCode": @(GCKeyCodeF2)},
        @{@"kind": @"button", @"aliases": @[@"F3"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @56, @"keyCode": @(GCKeyCodeF3)},
        @{@"kind": @"button", @"aliases": @[@"F4"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @57, @"keyCode": @(GCKeyCodeF4)},
        @{@"kind": @"button", @"aliases": @[@"F5"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @58, @"keyCode": @(GCKeyCodeF5)},
        @{@"kind": @"button", @"aliases": @[@"F6"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @59, @"keyCode": @(GCKeyCodeF6)},
        @{@"kind": @"button", @"aliases": @[@"F7"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @60, @"keyCode": @(GCKeyCodeF7)},
        @{@"kind": @"button", @"aliases": @[@"F8"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @61, @"keyCode": @(GCKeyCodeF8)},
        @{@"kind": @"button", @"aliases": @[@"F9"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @62, @"keyCode": @(GCKeyCodeF9)},
        @{@"kind": @"button", @"aliases": @[@"F10"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @63, @"keyCode": @(GCKeyCodeF10)},
        @{@"kind": @"button", @"aliases": @[@"F11"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @64, @"keyCode": @(GCKeyCodeF11)},
        @{@"kind": @"button", @"aliases": @[@"F12"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @65, @"keyCode": @(GCKeyCodeF12)},
        @{@"kind": @"button", @"aliases": @[@"PrintScreen"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @66, @"keyCode": @(GCKeyCodePrintScreen)},
        @{@"kind": @"button", @"aliases": @[@"ScrollLock"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @67, @"keyCode": @(GCKeyCodeScrollLock)},
        @{@"kind": @"button", @"aliases": @[@"Pause"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @68, @"keyCode": @(GCKeyCodePause)},
        @{@"kind": @"button", @"aliases": @[@"Insert"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @69, @"keyCode": @(GCKeyCodeInsert)},
        @{@"kind": @"button", @"aliases": @[@"Home"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @70, @"keyCode": @(GCKeyCodeHome)},
        @{@"kind": @"button", @"aliases": @[@"PageUp"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @71, @"keyCode": @(GCKeyCodePageUp)},
        @{@"kind": @"button", @"aliases": @[@"DeleteForward"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @72, @"keyCode": @(GCKeyCodeDeleteForward)},
        @{@"kind": @"button", @"aliases": @[@"End"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @73, @"keyCode": @(GCKeyCodeEnd)},
        @{@"kind": @"button", @"aliases": @[@"PageDown"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @74, @"keyCode": @(GCKeyCodePageDown)},
        @{@"kind": @"button", @"aliases": @[@"RightArrow"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @75, @"keyCode": @(GCKeyCodeRightArrow)},
        @{@"kind": @"button", @"aliases": @[@"LeftArrow"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @76, @"keyCode": @(GCKeyCodeLeftArrow)},
        @{@"kind": @"button", @"aliases": @[@"DownArrow"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @77, @"keyCode": @(GCKeyCodeDownArrow)},
        @{@"kind": @"button", @"aliases": @[@"UpArrow"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @78, @"keyCode": @(GCKeyCodeUpArrow)},
        @{@"kind": @"button", @"aliases": @[@"KeypadNumLock"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @79, @"keyCode": @(GCKeyCodeKeypadNumLock)},
        @{@"kind": @"button", @"aliases": @[@"KeypadSlash"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @80, @"keyCode": @(GCKeyCodeKeypadSlash)},
        @{@"kind": @"button", @"aliases": @[@"KeypadAsterisk"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @81, @"keyCode": @(GCKeyCodeKeypadAsterisk)},
        @{@"kind": @"button", @"aliases": @[@"KeypadHyphen"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @82, @"keyCode": @(GCKeyCodeKeypadHyphen)},
        @{@"kind": @"button", @"aliases": @[@"KeypadPlus"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @83, @"keyCode": @(GCKeyCodeKeypadPlus)},
        @{@"kind": @"button", @"aliases": @[@"KeypadEnter"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @84, @"keyCode": @(GCKeyCodeKeypadEnter)},
        @{@"kind": @"button", @"aliases": @[@"Keypad1"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @85, @"keyCode": @(GCKeyCodeKeypad1)},
        @{@"kind": @"button", @"aliases": @[@"Keypad2"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @86, @"keyCode": @(GCKeyCodeKeypad2)},
        @{@"kind": @"button", @"aliases": @[@"Keypad3"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @87, @"keyCode": @(GCKeyCodeKeypad3)},
        @{@"kind": @"button", @"aliases": @[@"Keypad4"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @88, @"keyCode": @(GCKeyCodeKeypad4)},
        @{@"kind": @"button", @"aliases": @[@"Keypad5"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @89, @"keyCode": @(GCKeyCodeKeypad5)},
        @{@"kind": @"button", @"aliases": @[@"Keypad6"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @90, @"keyCode": @(GCKeyCodeKeypad6)},
        @{@"kind": @"button", @"aliases": @[@"Keypad7"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @91, @"keyCode": @(GCKeyCodeKeypad7)},
        @{@"kind": @"button", @"aliases": @[@"Keypad8"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @92, @"keyCode": @(GCKeyCodeKeypad8)},
        @{@"kind": @"button", @"aliases": @[@"Keypad9"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @93, @"keyCode": @(GCKeyCodeKeypad9)},
        @{@"kind": @"button", @"aliases": @[@"Keypad0"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @94, @"keyCode": @(GCKeyCodeKeypad0)},
        @{@"kind": @"button", @"aliases": @[@"KeypadPeriod"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @95, @"keyCode": @(GCKeyCodeKeypadPeriod)},
        @{@"kind": @"button", @"aliases": @[@"KeypadEqualSign"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @96, @"keyCode": @(GCKeyCodeKeypadEqualSign)},
        @{@"kind": @"button", @"aliases": @[@"NonUSBackslash"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @97, @"keyCode": @(GCKeyCodeNonUSBackslash)},
        @{@"kind": @"button", @"aliases": @[@"Application"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @98, @"keyCode": @(GCKeyCodeApplication)},
        @{@"kind": @"button", @"aliases": @[@"Power"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @99, @"keyCode": @(GCKeyCodePower)},
        @{@"kind": @"button", @"aliases": @[@"International1"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @100, @"keyCode": @(GCKeyCodeInternational1)},
        @{@"kind": @"button", @"aliases": @[@"International2"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @101, @"keyCode": @(GCKeyCodeInternational2)},
        @{@"kind": @"button", @"aliases": @[@"International3"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @102, @"keyCode": @(GCKeyCodeInternational3)},
        @{@"kind": @"button", @"aliases": @[@"International4"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @103, @"keyCode": @(GCKeyCodeInternational4)},
        @{@"kind": @"button", @"aliases": @[@"International5"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @104, @"keyCode": @(GCKeyCodeInternational5)},
        @{@"kind": @"button", @"aliases": @[@"International6"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @105, @"keyCode": @(GCKeyCodeInternational6)},
        @{@"kind": @"button", @"aliases": @[@"International7"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @106, @"keyCode": @(GCKeyCodeInternational7)},
        @{@"kind": @"button", @"aliases": @[@"International8"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @107, @"keyCode": @(GCKeyCodeInternational8)},
        @{@"kind": @"button", @"aliases": @[@"International9"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @108, @"keyCode": @(GCKeyCodeInternational9)},
        @{@"kind": @"button", @"aliases": @[@"LANG1"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @109, @"keyCode": @(GCKeyCodeLANG1)},
        @{@"kind": @"button", @"aliases": @[@"LANG2"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @110, @"keyCode": @(GCKeyCodeLANG2)},
        @{@"kind": @"button", @"aliases": @[@"LANG3"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @111, @"keyCode": @(GCKeyCodeLANG3)},
        @{@"kind": @"button", @"aliases": @[@"LANG4"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @112, @"keyCode": @(GCKeyCodeLANG4)},
        @{@"kind": @"button", @"aliases": @[@"LANG5"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @113, @"keyCode": @(GCKeyCodeLANG5)},
        @{@"kind": @"button", @"aliases": @[@"LANG6"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @114, @"keyCode": @(GCKeyCodeLANG6)},
        @{@"kind": @"button", @"aliases": @[@"LANG7"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @115, @"keyCode": @(GCKeyCodeLANG7)},
        @{@"kind": @"button", @"aliases": @[@"LANG8"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @116, @"keyCode": @(GCKeyCodeLANG8)},
        @{@"kind": @"button", @"aliases": @[@"LANG9"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @117, @"keyCode": @(GCKeyCodeLANG9)},
        @{@"kind": @"button", @"aliases": @[@"LeftControl"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @118, @"keyCode": @(GCKeyCodeLeftControl)},
        @{@"kind": @"button", @"aliases": @[@"LeftShift"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @119, @"keyCode": @(GCKeyCodeLeftShift)},
        @{@"kind": @"button", @"aliases": @[@"LeftAlt"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @120, @"keyCode": @(GCKeyCodeLeftAlt)},
        @{@"kind": @"button", @"aliases": @[@"LeftGUI"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @121, @"keyCode": @(GCKeyCodeLeftGUI)},
        @{@"kind": @"button", @"aliases": @[@"RightControl"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @122, @"keyCode": @(GCKeyCodeRightControl)},
        @{@"kind": @"button", @"aliases": @[@"RightShift"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @123, @"keyCode": @(GCKeyCodeRightShift)},
        @{@"kind": @"button", @"aliases": @[@"RightAlt"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @124, @"keyCode": @(GCKeyCodeRightAlt)},
        @{@"kind": @"button", @"aliases": @[@"RightGUI"], @"local": [NSNull null], @"unmappedLocal": [NSNull null], @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @0, @"system": @0, @"collection": [NSNull null], @"order": @125, @"keyCode": @(GCKeyCodeRightGUI)},
    ];
    self = [super initWithCharonSpecs:specs];
    if (!self)
        return nil;
    NSMutableDictionary *byCode = [NSMutableDictionary dictionaryWithCapacity:specs.count];
    for (NSDictionary *spec in specs)
        byCode[@([spec[@"keyCode"] intValue])] = [self charon_elementNamed:[spec[@"aliases"] firstObject]];
    _byKeyCode = byCode;
    _anyKeyPressed = NO;
    return self;
}

- (GCKeyboardValueChangedHandler)keyChangedHandler
{
    return _keyChangedHandler;
}

- (void)setKeyChangedHandler:(GCKeyboardValueChangedHandler)keyChangedHandler
{
    _keyChangedHandler = [keyChangedHandler copy];
}

- (BOOL)isAnyKeyPressed
{
    return _anyKeyPressed;
}

// One list of specs is the whole table: the map is built from it in -init, so a key code with
// no spec row has no button and answers nil, and nothing here can drift from the specs.
- (GCDeviceButtonInput *)buttonForKeyCode:(GCKeyCode)code
{
    return (id)_byKeyCode[@((int)code)];
}

// The one thing that moves a keyboard: a key changes value, its own handlers run through the
// element, and the profile's handler runs for that key alone, which is what the header's note
// says - once per key that changed, not once per event.
- (void)charon_setPressed:(BOOL)pressed forKeyCode:(GCKeyCode)code value:(float)value
{
    GCControllerButtonInput *key = (id)_byKeyCode[@((int)code)];
    if (!key)
        return;
    [key setValue:value];
    if (pressed)
        _anyKeyPressed = YES;
    else {
        for (GCControllerButtonInput *other in _byKeyCode.allValues) {
            if (other.isPressed) {
                _anyKeyPressed = YES;
                return;
            }
        }
        _anyKeyPressed = NO;
    }
    GCKeyboardValueChangedHandler handler = _keyChangedHandler;
    if (!handler)
        return;
    BOOL isPressed = key.isPressed;
    GCKeyboardInput *keyboard = self;
    dispatch_queue_t queue = self.device.handlerQueue ?: dispatch_get_main_queue();
    dispatch_async(queue, ^{
        handler(keyboard, key, code, isPressed);
    });
}

@end
