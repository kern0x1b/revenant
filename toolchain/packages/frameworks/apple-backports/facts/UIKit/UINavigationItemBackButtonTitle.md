# The back button title of a navigation item, iOS 11.0

Introduced in iOS 11.0: an item can say, in one string, what the back button
should read when the next item is pushed on top of it - without building a
whole bar button item for it.

Source: UIKit of the arm64 shared cache of iOS 11.0 (iPod7,1 15A372),
`-[UINavigationItem backButtonTitle]` at `0x18a043a9c`, `-setBackButtonTitle:`
at `0x18a043618` through `-_setBackButtonTitle:lineBreakMode:` at
`0x18a043628`, and `-currentBackButtonTitle` at `0x18a04e8e8`, which is where
the order below is decided. Also: the method lists of `UINavigationItem` in
every UIKit this package has, from 3.0 to 10.3.4, and a run on an iPhone 4S
(6.1.3).

## What it is and what it is not

The setter copies the string into an ivar of its own and tells the bar that the
back button's content changed, so that it can draw again. It does **not**
touch `backBarButtonItem`, and `backBarButtonItem` does not touch it:
- an item given only a title answers `nil` for the item;
- an item given only an item answers `nil` for the title;
- an item given both keeps both, whichever came first.

The two meet in `-currentBackButtonTitle`, which is what the bar actually
draws:
1. if `backBarButtonItem` is there, its `title` wins;
2. otherwise the `backButtonTitle`;
3. otherwise the item's own `title`, shortened if it has to be.

## The release carries it

`-backButtonTitle` and `-setBackButtonTitle:` are not new in iOS 11: UIKit has
had them on `UINavigationItem` as private methods on every release this package
reads - 3.0, 3.1.3, 3.2, 4.0, 4.3.5, 5.0, 5.1.1, 6.0, 6.1.3, 7.0, 8.0, 9.0,
10.0.1 and 10.3.4. iOS 11 made them public. Categories are attached only where
the class does not answer, so there is nothing for this package to attach, and
it carries no code for this property: what an application gets is the
release's own method.

In the registry the entry is therefore `ignored`, the status for a call that
reaches the release's own implementation with nothing of ours in the way. It is
not `implemented`, because the build checks that an implemented entry names
something the package builds, and here there is nothing to build. It has no
`minimum`: the release answers on every version this package reads, so there is
no release below which the property is missing.

That method behaves as the iOS 11 one does, measured on an iPhone 4S running
6.1.3.

What the property answers, against the host's UIKit, which gave the same answer
at every step:
- a fresh item has none;
- the title comes back as it was set, copied on the way in;
- an item of the application's own is not a title;
- a title and an item each stay whichever was set first;
- the last title wins;
- `nil` clears it.

What the bar draws, read off the views of a real `UINavigationBar` with a second
item pushed on the first:
- the title set: `Up`;
- a title and an application's own item, in either order: `Item`;
- a title set and then set to `nil`: the item's own title, `Home`;
- neither: `Home`.

`backBarButtonItem` stays `nil` after a title is set.

So on this release there is no divergence from iOS 11 to write down.
