#import <Foundation/Foundation.h>

// UIDocumentBrowserTransitionController, as the 26.2 header declares it: two properties, and an
// -init the header marks unavailable. It names none of the browser's own types, so it needs none of
// the umbrella, for the same reason as the delegate protocol beside it: the SDK declares this class
// too, and importing it would bring the SDK's copy in beside this one. What this header names --
// NSProgress, UIView, and the one protocol the class conforms to -- is what a translation unit
// reading it has to have forward declarations for, and the check's does.
//
// A transcription, like the delegate protocol beside it, and for the same reason: a 6.1.3-era SDK has
// no document browser at all. tests/backports/host/documentbrowser/ast_check.py compares this against
// the header with the same AST reading it uses for the protocol -- selector by mangledName, and the
// property's type, nullability and attributes from the AST's own qualType and keys -- with a control
// that flips one attribute and is required to be caught.

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(watchos, tvos)
@interface UIDocumentBrowserTransitionController : NSObject <UIViewControllerAnimatedTransitioning>

- (instancetype)init NS_UNAVAILABLE;

/* The progress of the document being loaded, so a transition can show it. */
@property (strong, nonatomic, nullable) NSProgress *loadingProgress;

/* The view the transition animates to. */
@property (weak, nullable, nonatomic) UIView *targetView;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
