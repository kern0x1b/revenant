// CharonCoreML.h — what the port's `CoreML` Swift module sees of CoreML's own headers.
//
// The port's shaped-array overlay is a Swift module named `CoreML`, and so is the SDK's CoreML as a
// *clang* module. Two modules cannot share a name, and the Swift one wins: a module named `CoreML`
// that says `import CoreML` is importing itself, and the framework's declarations are not in scope.
// That is the same situation charon's swift-runtime is in for `Foundation`, `UIKit` and `CoreData`,
// and it is solved the same way — the Swift module is given a header of its own that includes the
// framework's, and is built with `-import-objc-header` so the declarations are in the module
// directly.
//
// **What is included, and what is not.** One header, for one declaration: `MLMultiArrayDataType`,
// which is the single thing the shaped-array overlay needs and which the whole linear family of
// CreateMLComponents is blocked on. `MLMultiArray.h` is included rather than the enum being declared
// here, so this is the framework's own declaration and not a second copy of it — the same
// declaration, reaching the module by a different route. The class `MLMultiArray` comes with the
// header and is NOT used: it is absent from the port's release, it is in
// `registry/CoreML/absent_CoreML.json`, and no part of this package names it.

#import <CoreML/MLMultiArray.h>
