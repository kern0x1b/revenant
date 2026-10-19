# UIWindowSceneGeometryPreferences and UIWindowSceneGeometryPreferencesIOS, iOS 16

Source: the SDK 16.4 headers `UIWindowSceneGeometryPreferences.h` and `UIWindowSceneGeometryPreferencesIOS.h`,
which document the base class as empty and never initialized on its own, and the iOS subclass as one
property, `interfaceOrientations`, defaulting to an empty mask, plus the plain and orientation-taking
initializers.

## What the port does

Both classes are carried as real, allocable classes: `UIWindowSceneGeometryPreferences` is the documented
empty base, and `UIWindowSceneGeometryPreferencesIOS` holds the `interfaceOrientations` mask it is given
(`0` from the plain `-init`, matching the header's documented default of no preference). An application
that constructs one of these to hand to `-[UIWindowScene requestGeometryUpdateWithPreferences:errorHandler:]`
no longer crashes doing so.

## What the port does not do

`-[UIWindowScene requestGeometryUpdateWithPreferences:errorHandler:]` itself is not carried: it is not in
this file's registry entry and remains a genuine gap, unconnected to this class pair. iOS 6.1.3 has one
scene and one screen at a fixed size; there is no multi-window geometry for a preference to act on, only
the existing single-scene rotation surface (`-[UIWindowScene interfaceOrientation]`,
`+[UIViewController attemptRotationToDeviceOrientation]`) that this class pair does not currently reach.
Wiring the request method to that surface is future work, not attempted here because nothing in the
corpus's confirmed demand calls it - the demand this file answers is a `LOAD-FAIL` on the class symbol
itself, from constructing the preferences object, not from the request call.
