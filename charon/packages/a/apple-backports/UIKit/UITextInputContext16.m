// UITextInputContext16.m - the class of iOS 16.4 that says which input the user is about to use, so
// the keyboard can put up the right one: a pencil, dictation, or a hardware keyboard.
//
// What the host answers was measured first (facts/UIKit/HoverAndTextInput16.md), and it is not what the
// header's shape suggests. On the host's own UIKit under Mac Catalyst the class exists and its superclass
// is NSObject, but `+current` hands back a context of its own on every call rather than a shared one,
// `+new` works although the header marks it NS_UNAVAILABLE, and the three flags read NO on a fresh
// context, after all three setters have run, and after a second `+current`. The setters keep nothing.
//
// That is what this release has to match. iOS 6 has no pencil, no dictation and no attached hardware
// keyboard, so there is nothing for a flag to name and nothing on the release that would read one; the
// three properties therefore answer NO and keep nothing, which is what the host's own class does here.
// The class and the two ways of having one are carried so that a caller compiled against 16.4 links and
// runs; what a caller cannot get on this release is any effect from the three flags, and the registry
// row says so.
//
// One object, one release: this file is 16.4 API only. The four members of UIHoverGestureRecognizer
// that arrived in 16.1 and 16.4 are in UIHoverGestureRecognizer+Hover16.m, and UISearchBar's enabled of
// 16.4 is left to the release's own UIView accessors, as the same facts page measures.

#import <UIKit/UIKit.h>

@implementation UITextInputContext

// The header marks -init and +new NS_UNAVAILABLE and gives +current as the only way to have one. The
// measurement says otherwise on the host, so both are here and +current is what the header's callers
// reach for. The flags are the three properties above; they are answered rather than stored, because
// this release has none of the three inputs they name, and the host's own class does the same here.
- (BOOL)isPencilInputExpected
{
    // No pencil on this release, and the host's own class reads 0 here too: facts/UIKit/HoverAndTextInput16.md.
    return NO;
}

- (BOOL)isDictationInputExpected
{
    // No dictation on this release, and the host's own class reads 0 here too.
    return NO;
}

- (BOOL)isHardwareKeyboardInputExpected
{
    // No attached hardware keyboard on this release, and the host's own class reads 0 here too.
    return NO;
}

// The three setters keep nothing, and that is the measurement rather than a stub: the host's own class
// reads 0 after all three have been run with YES, and from a second +current. What there is to keep -
// a pencil, dictation, an attached keyboard - is not on this release.
- (void)setPencilInputExpected:(BOOL)expected
{
}

- (void)setDictationInputExpected:(BOOL)expected
{
}

- (void)setHardwareKeyboardInputExpected:(BOOL)expected
{
}

+ (UITextInputContext *)current
{
    return [[self alloc] init];
}

@end
