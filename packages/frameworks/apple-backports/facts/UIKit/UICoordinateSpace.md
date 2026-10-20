# UICoordinateSpace, iOS 8

Introduced in iOS 8.0: the protocol of a space that has bounds and converts points and rectangles to and from another - a
view, a window, and the two spaces of a screen - with `-[UIScreen coordinateSpace]` and `-[UIScreen fixedCoordinateSpace]`, and
`convertPoint:toCoordinateSpace:`, `convertPoint:fromCoordinateSpace:`, `convertRect:toCoordinateSpace:` and
`convertRect:fromCoordinateSpace:` on `UIView` (and so on `UIWindow`).

Source: the host's own UIKit under Mac Catalyst (`host/coordspace/run.sh`): 29 answers over nested views, a sibling, the window and
both screen spaces - the protocol on a view, a window and a screen space; the same screen space object each time; points and
rectangles of one view in another, in the window and in each screen space, and back; a screen space to the other and to a view; the
bounds of a view and of the fixed screen space. `device/coordspace.m` holds iOS 6 to them on the iPhone 4S and the iPad 2.

## What the port does as the system does

A view converts through `convertPoint:toView:` when the other space is a view of its own window, and through the screen otherwise.
The rotating screen space is the coordinate space of the windows of the application - the window's own, turned with the interface
orientation - and the fixed screen space is the screen's in portrait, with its origin at the top left of the device; the release's
`convertPoint:toWindow:nil` is the screen's, so a point goes to the fixed space that way and comes back with
`convertPoint:fromWindow:nil`. The screen spaces answer the bounds of the screen as it is turned and as it is fixed, and
convert points and rectangles to each other, to a view and to a window by the same two steps. A rectangle is converted by its four
corners, which is exact for the quarter turns of the two screen spaces. A view or a window that is in no window keeps the point it
was given. The protocol is added to `UIView` at load, so `conformsToProtocol:` answers YES for a view, a window and a screen space.

## What differs

The rotating space is the reference window's - the key window, or the first - so an application with windows turned differently
from one another gets the key window's answer. The host converts through the scene of its window; the port has no scene, and the
screen spaces of a `UIWindowScene` and of the screen are two objects that answer alike.
