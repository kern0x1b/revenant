# How it works

Apple's SwiftUI cannot run on iOS 6: it has never had an armv7 build, it needs Metal, and it drags in over four hundred
system images the phone does not have. So this project re-implements the *API* instead, on the UIKit of iOS 6, with
[Combine](../../reference/combine/features.md), a Combine for iOS 6, standing in for Apple's Combine. An app written in
ordinary SwiftUI syntax compiles against it and comes out as a native-looking iOS 6 app on a phone from 2011.

The module keeps Apple's name on purpose: the mangled names of every symbol an app takes from SwiftUI depend on it.
The project, its directory and its build targets carry the same name.

- **Node tree.** Every view becomes a node. Primitive views (`Text`, `Button`, stacks) own UIKit views; composite views
  own a child node and re-evaluate `body` when their state changes.
- **Reconciliation.** A node is reused when the type of its view is unchanged, and skipped entirely when the view's bytes
  and the environment are unchanged. `if`/`else` branches are distinct identities, as in SwiftUI.
- **Dependencies.** A view's stored properties are read reflectively once per type, so `@State` and `@ObservedObject`
  find their nodes without code generation.
- **Layout.** Sizes are proposed and reported in points, cached per node, and applied to UIViews by size and centre.
  Only the nodes marked dirty are laid out again.
- **Animation.** Ordinary properties are handed to `UIView.animate`; data that UIKit cannot interpolate is driven frame
  by frame by a display-link animator.
- **Combine** is `frameworks/Combine`, built with the same Swift runtime; it is a module named `Combine`, so apps write `import Combine`.
