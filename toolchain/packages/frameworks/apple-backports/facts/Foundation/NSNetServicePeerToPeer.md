# NSNetService.includesPeerToPeer and NSNetServiceBrowser.includesPeerToPeer, iOS 7

Introduced in iOS 7.0: whether a service is published, resolved or browsed for over the peer-to-peer (Bluetooth and peer-to-peer Wi-Fi) interface as well as the networks the device is on.

iOS 6 has no such interface for Bonjour, so the two are `inert`: the value is kept and read back (NO at first, as the host has it), and publishing, resolving and browsing use the networks the device is on.
`device/smallapis2.m` reads the defaults and what is kept for the service and the browser.
