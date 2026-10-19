# Drag and drop

The coordinator's ruling (2026-09-27): a drag is software. The sessions, the items, the previews, the
proposals and the interaction's gestures all live in the process and are fully implementable on this
release. Where a drag would leave the application, the answer is what Apple documents for an iPhone of
this era: cross-app drag is not offered.

## What the release cannot do, and what that means for one API

A drag on a real device is begun, carried and ended by a system service, and that service is what
lets a drag leave the application. This release has no such service, so:

- **inside the application a drag is real.** A long press lifts, a pan carries a preview across the
  application's own windows, a drop asks the delegate and the item provider's data moves. All of that
  is in this process and none of it needs the missing service.
- **a drag that would leave the application is not offered.** Where a session is asked what it may do,
  or where the drop is asked to accept something from outside, the answer is the one a device of this
  era gives, and it is recorded at each such seam rather than left to look like a working cross-app
  drag.

Four entries another band registered `absent` with the reason "a drag is begun, carried between
applications and ended by a system service this release does not have" are now `implemented`: that
reason is true of the part that leaves the application and false of everything in it, which is the
whole of these value objects. Their entries have moved from `registry/UIKit/ios11.json` to
`registry/UIKit/dragdrop.json`.

## Six protocols were registered absent for the same false reason, and the port emits them

`UIDragSession`, `UIDragAnimating`, `UIDragInteractionDelegate`, `UIDropInteractionDelegate`,
`UITextDragRequest` and `UITextDropRequest` carried that identical `absent` reason and the effect
"the name is not there: an application that asks for it before dragging keeps the path it has for a
release without dragging". The port's own objects emit all six, which is what that effect denies.

Measured, not read off the source: the seventeen sources that name any row of this family compiled
for the port's own target (`clang -target armv7-apple-ios6.1.3` against the 16.4 SDK, all seventeen
exit 0), and each object's `__objc_protolist` read through the tree's own Mach-O reader and its own
relocation reading — an object file has no bind opcodes, so a pointer to a symbol another file
defines is an external relocation of the pointer's size:

    UIDropSession.o            NSObject NSProgressReporting UIDragDropSession UIDragSession UIDropSession
    CharonDropCoordinatorObjects.o  NSObject UICollectionViewDropCoordinator
                                UICollectionViewDropPlaceholderContext UIDragAnimating
                                UITableViewDropCoordinator UITableViewDropPlaceholderContext
    UITextView+TextDragDrop11.o NSObject UIDragInteractionDelegate UIDropInteractionDelegate
                                UITextDragRequest UITextDropRequest

`__objc_protolist` is the list the runtime reads at load time, so a protocol in it is a protocol
`NSProtocolFromString` answers and a class can conform to. The negative control: the four sibling
protocols this family uses only as type qualifiers — `UITextDraggable`, `UITextDroppable`,
`UITextDragDelegate`, `UITextDropDelegate` — are in none of these lists and stay `absent`, and so do
`UIFocusSystem`, `UIPasteConfiguration`, `UISpringLoadedInteraction` and
`UIAccessibilityContainerDataTable`, which nothing in the port names at all. The same 20 names across
all seventeen objects is what a working reader produces, and the four that should read false do.

So the six are `implemented` and their reason is gone: a drag here IS lifted, carried and dropped in
one process, and the protocol that says so is what the port's objects already emit.

## The previews duplicate nothing

`UIDragPreviewParameters` is a subclass of `UIPreviewParameters` and `UIDragPreviewTarget` of
`UIPreviewTarget`, both of which the tree already carries for the peek and pop preview — down to the
precondition `UIPreviewTarget` raises on when its container is not in a window. `UITargetedDragPreview`
is a `UITargetedPreview`, likewise carried, including its own retargeting. So these are the drag's own
names for objects that already exist here, and this family adds nothing to them; the header's
subclassing says exactly that, and the only thing the drag adds is its own types on top.

A `UIDragPreview` is a still picture: it neither moves nor changes the view it was made from, which is
what the header says, so nothing here takes a snapshot eagerly and the view is left alone.

## The sessions, the proposals and the two interactions

**The gestures are the release's own**, which is what makes this a drag and not a swipe: a
`UILongPressGestureRecognizer` at half a second lifts what is under the touch and a
`UIPanGestureRecognizer` carries the picture that lift made, and letting go is the drop. The preview
is a still picture of a view — rendered from its layer, as the tree's own movement preview does — and
it is added to the application's own window and travels between the application's own windows.

There is **no drag that leaves the application** and none is faked: a session answers
`isRestrictedToDraggingApplication` YES, which is the answer a device of this era gives, and the
delegate is asked about it so the application sees the answer rather than having it assumed. A move is
allowed, because a move inside the application needs no service.

A drop is found by asking: the drag carries the list of drop interactions the application made, and
the one whose view is under the finger is asked `canHandleSession:`, then told `sessionDidEnter:` and
`sessionDidUpdate:` as the finger moves, and on letting go told `performDrop:`, `concludeDrop:` and
`sessionDidEnd:`. The drag's own delegate is told what the drag ended with, and a drag that was
called off ends as cancelled.

**The data is the item provider's.** `loadObjectsOfClass:completion:` loads through the provider that
carries it; nothing here copies a payload.

**A lift with no delegate says nothing is being dragged.** A view cannot go into an item provider on
this release — a provider writes objects that can be read back, and a view is not one — and guessing
a payload would move the wrong data, so the lift ends there rather than dragging something invented.

`UITargetedDragPreview` is given **no** way to make one: the header declares no initialiser, because
the system hands the preview to the delegate it asks. The port therefore constructs none, and adds
nothing to the `UITargetedPreview` the tree already carries beyond the retargeting the header does
declare. Three more entries another band held `absent` for the same soft reason as the previews have
moved to `implemented`.

## The coordinators, the drop items and the placeholders

The coordinators, the drop items, the placeholder contexts and the four delegate protocols are
**protocols in the header, not classes**, so the port supplies the objects that answer them: the
release has none, because it has no drop. Where an item would land comes from the release's own
`indexPathForItemAtPoint:` and `indexPathForRowAtPoint:`, and the size its preview is drawn at from
the layout that gives the item it would land on — nothing here invents a position.

A placeholder is where an item will be once the data source has been told about it: the index path it
stands at, the cell it is drawn with, and a block that hands that cell over, which is how a delegate
draws a cell for a row that does not exist yet. A drop placeholder is the same thing plus the
parameters its preview is built from.

## The two silent fakes are now real

`-[UICollectionView hasActiveDrag]`, `-[UICollectionView hasActiveDrop]` and their table view twins
answered a constant `NO` while the registry called them implemented. They answer from the sessions
that now exist: a view has an active drag when one of its drag interactions is carrying something, and
an active drop when a session of its own is under the finger. Both change with the drag, which is what
makes them worth having.

## What this family does not yet do

The delegate **questions** are carried and the view asks the ones it can (`charon_dropItemsAtPoint:
session:` finds the items under a point for a drop delegate). The rest — the drag delegate's
`itemsForBeginningDragSession:` being routed from a view's own long press, and the drop coordinator
objects that answer `dropItem:toItemAtIndexPath:` and its three siblings — are not built. The
coordinator protocol is carried and its objects are the next piece of this family, not a separate
one.
