# UIViewController setNeedsUpdateOfSupportedInterfaceOrientations, iOS 16

Source: UIKit of iOS 16.0 arm64e, `-[UIViewController setNeedsUpdateOfSupportedInterfaceOrientations]` at `0x189671fa0`, read; the
SDK 16.4 header of `UIViewController.h`; and iOS 6.0 on the emulator and iOS 6.1.3 on an iPad 2 and an iPhone 4S, through
`tests/backports/device/ios1516.m`.

## What is read of the newest release

The method is a short call sequence that hands the request to the view controller's orientation machinery and returns; what
that machinery does is UIKit's own and is not read here. What the header of the SDK says, twice, is enough for the port: the
method "notifies the view controller that a change occurred that affects supported interface orientations or the preferred
interface orientation for presentation", and the class method `+attemptRotationToDeviceOrientation`, available from iOS 5,
carries the deprecation "Please use instance method `setNeedsUpdateOfSupportedInterfaceOrientations`": one is the other's
replacement.

## What the port does

`-setNeedsUpdateOfSupportedInterfaceOrientations` sends `+attemptRotationToDeviceOrientation` of iOS 6, which asks the system to
ask the view controller for its orientations again and to rotate if the device is turned to one it now supports. The header
of the newest release says the update animates unless it is made inside `+[UIView performWithoutAnimation:]`; the release's own
rotation animates as it does and the port does not draw the rotation itself, so that is what an application gets.

## What was measured

A view controller made on the emulated iOS 6.0, the iPad 2 and the iPhone 4S answers the selector and takes the call without
raising, in a process with no application; the rotation itself, which needs an application on the screen, was not observed.
