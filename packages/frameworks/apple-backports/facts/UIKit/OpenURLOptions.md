# Opening a URL with options, iOS 9

From iOS 9 an application that is sent a URL gets `-application:openURL:options:` on its delegate, with a dictionary that
holds `UIApplicationOpenURLOptionsSourceApplicationKey` (the bundle identifier of the sender, when there is one),
`UIApplicationOpenURLOptionsAnnotationKey` (the annotation, when there is one) and
`UIApplicationOpenURLOptionsOpenInPlaceKey` (an `NSNumber`, NO unless the sender allowed opening the document in place).
The release sends `-application:openURL:sourceApplication:annotation:` and knows nothing of the new one, so an application
that implements only the new form would never be given a URL.

The port bridges it. When the application's delegate is set, and its class has `-application:openURL:options:` and not the
old form, the old form is added to the class and calls the new one with the dictionary above: the source and the annotation
only when the release gave them, and open-in-place always NO, since nothing on this release opens a document in place.
A delegate that has the old form is left alone, as is one that has neither.

`UIApplicationOpenURLOptionsAnnotationKey` is new with the bridge, the other two keys are carried since before and now
appear in the dictionary they belong to.

Source: the shared caches of iOS 9 and 10 for the key names and the call; `tests/backports/device/openurl.m`, which sends
an application a real URL on the device and reads what its delegate is given.
