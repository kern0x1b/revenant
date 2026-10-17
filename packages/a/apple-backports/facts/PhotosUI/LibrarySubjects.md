# The three rows that wait on a Photos row

`PHLivePhotoView`, `PHLivePhotoViewDelegate` (both iOS 9.1) and `PHContentEditingController`
(iOS 8) are the three rows of this family that are not built, and all three are waiting on the
same thing: a row of Photos that another band adjudicates. They are in
`registry/PhotosUI/absent_PhotosUI.json`, and the rows they wait on are in
`registry/Photos/absent_Photos.json`. Nothing here is a wall - the port can carry all three -
and nothing here is a debt of this family either, because this family cannot carry a row whose
subject is absent.

Source: `PHLivePhotoView.h` and `PHContentEditingController.h` of the iOS 16.4 SDK and of the
iOS 26.2 SDK, for what each row declares and what its members take;
`sdk-26.2-surface.tsv` for the same three by name, kind and introduced release; and
`tools/cache-index/first-rung.lua` over the 50 held rungs, which reads `PHLivePhotoView` first
at 9.1, `PHLivePhotoViewDelegate` at 9.2 and `PHContentEditingController` at 8.0 - so no
release this port carries below them holds any of the three. The delegate's name appearing a
release after its class's is what a name's first appearance measures; the header's own
availability for both is 9.1.

## PHLivePhotoView and PHLivePhotoViewDelegate

The class's whole content is a live photo. `livePhoto` is a `PHLivePhoto *`, the two playback
methods play one, `+livePhotoBadgeImageWithOptions:` draws the badge that says there is one,
and each of the four delegate methods is about a playback of the view. The port carries no
`PHLivePhoto`: `registry/Photos/absent_Photos.json` lists it absent, with `PHLivePhotoRequestOptions`
and the three info keys beside it, and those rows belong to the Photos family.

So the view has nothing to show and the delegate nothing to be asked about. Carrying the class
over a subject that is absent would mean a `UIView` subclass whose one property cannot be
declared, because the type it holds does not exist in this port - and a row that says
`implemented` for that is the silent fake the registry's own vocabulary has a word against.

When the Photos family carries `PHLivePhoto`, this view is a small piece of work, and the port
already has both halves of it: the still image for the badge and for the paused state is what
`-[PHImageManager requestImageForAsset:targetSize:contentMode:options:]` answers
(`PHImageManager8.m:189`), and the movie to play over it is what
`-[PHImageManager requestPlayerItemForVideo:options:]` answers (`PHImageManager8.m:283`).

## PHContentEditingController

The protocol is the interface a photo editing extension's principal view controller
conforms to, and its three required methods take `PHContentEditingInput` (what to edit),
`PHContentEditingOutput` (what came of it) and `PHAdjustmentData` (whether the controller can
handle an adjustment). All three are absent rows of Photos, and the fourth part of the same
puzzle - `PHContentEditingRequestOptions`, the request the app makes - is a fourth.

There is a second reason, and it is the reason the header gives for the method this port
does carry: iOS 6's photo library has no editing extension. A protocol with no caller is not
worth carrying for its own sake; a protocol whose every parameter is absent cannot be carried
at all.

## What would change the answer

One row from Photos, and the three rows here become buildable. Nothing in this family has to
be rewritten to make room for them: no header of this package names any of the three, and
`photos.tsv` in the queue names the Photos rows that carry the subjects.
