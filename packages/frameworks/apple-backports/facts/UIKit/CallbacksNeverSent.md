# Callbacks the release never sends, iOS 11.0 and 12.1

Two protocol members are declared by the SDK's headers and are called by classes and
services that iOS 6 does not have:

- `-[UIPencilInteractionDelegate pencilInteractionDidTap:]` is sent by
  `UIPencilInteraction`, which is absent: the Apple Pencil is a stylus with its own
  radio and sensors, and no device this package runs on has one.
- `-[UIApplicationDelegate application:handleIntent:completionHandler:]` is sent
  when the system's intents service hands an application an intent, and this
  release runs no such service.

Source: the SDK 16.4 headers. Nothing was read from a release: the point is that iOS 6
never calls either.

An application compiled with the protocol carries its metadata, so it builds and runs;
an application that implements either method is never called. That quiet failure is why
both are `ignored` and not left out of the registry.
