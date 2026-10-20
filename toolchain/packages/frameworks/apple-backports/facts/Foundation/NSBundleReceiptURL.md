# NSBundle.appStoreReceiptURL, iOS 7

Introduced in iOS 7.0: the location of the App Store receipt of an application, `StoreKit/receipt` in its bundle, which an application reads to tell whether it was bought.

iOS 6.1.3 has a method of the name already, and an application that asks `respondsToSelector:` is told yes, but calling it raises. The port therefore does not add the method: it
replaces the release's when the library loads, and answers the file URL of `StoreKit/receipt` in the bundle asked, as iOS 7 does. There is no receipt at it - an application
that runs on iOS 6 was installed by hand or by another store - so the URL is one of a file that is not there, which an application checks for and treats as no receipt.
`device/receipturl.m` asks the main bundle and a bundle of a folder on the device and checks the paths and that the call raises nothing.
