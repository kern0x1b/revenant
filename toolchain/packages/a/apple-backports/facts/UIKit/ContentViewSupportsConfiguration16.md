# -[UIContentView supportsConfiguration:], iOS 16.0

## The header

```objc
/// Whether this view is compatible with the provided configuration, meaning the view supports
/// it being set to the `configuration` property and is capable of updating itself for the
/// configuration. If not implemented, the view is assumed to be compatible with configuration classes
/// that match the class of the view's existing configuration.
- (BOOL)supportsConfiguration:(id<UIContentConfiguration>)configuration API_AVAILABLE(ios(16.0), tvos(16.0), watchos(9.0));
```

The header carries the answer in its own last sentence: a view that does not implement the method is
assumed compatible with configurations of the same kind as the one it holds. That is the rule the
port's install path already applies — `charon_install_content` in `CharonConfigurationHost.m` reuses
the installed view when `[configuration makeContentView]` is of the same class as the one it holds,
and makes a new view otherwise — so implementing the method answers the port's own test rather than a
second, weaker one.

## What the release carries, measured

```
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 > inv-6.1.3.tsv
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/12.0/dyld_shared_cache_arm64  > inv-12.0.tsv
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/16.0/dyld_shared_cache_arm64e > inv-16.0.tsv
```

```
6.1.3  UIListContentView: absent from the class list      UIView n=663   supportsConfiguration: none
12.0   UIListContentView: absent from the class list      UIView n=2156  supportsConfiguration: none
16.0   UIListContentView n=28                            supportsConfiguration: -supportsConfiguration:
```

`UIView` is the class both band ends carry and the protocol's only implementer, so this is a real
selector-level zero on rows that hold 663 and 2156 selectors: the reader is reading UIView's selector
list. The 16.0 line shows the release's own `UIListContentView` carries the method, which is what
places this API in the 16.0 band; the port's `UIListContentView` is its own class
(`UIListContentView.m`) and is what this object answers for.

## What the port does

`-[UIListContentView supportsConfiguration:]` returns YES when the configuration would install this
kind of view — the same test `charon_install_content` makes — and NO for a configuration that makes
another kind, so a caller can ask before replacing rather than after.

The port has exactly one content view: `-[UIListContentConfiguration makeContentView]` is the only
`makeContentView` in `UIKit/`, and it answers a `UIListContentView`. So in this port the answer is YES
for every list content configuration and NO for everything else, which is the whole of what the
header's rule can say with one content view in the process. It is not measured against the host: the
host has more content views (a `UIContentUnavailableConfiguration` one among them), and a
host differential for a one-line rule over a class this port does not have would compare two
different sets of classes.