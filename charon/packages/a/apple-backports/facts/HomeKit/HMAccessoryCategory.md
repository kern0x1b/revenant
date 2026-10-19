# HMAccessoryCategory, iOS 9.0

An accessory's category is named by a HAP UUID — a light bulb is
`57D56F4D-3302-41F7-AB34-5365AA180E81` — and `-categoryType` hands that UUID back. That much is
carried, and the UUIDs themselves are the ones read out of a real HomeKit (`HMConstants.md`).

`-localizedDescription` is **not** carried, and the reason is that it is a localized string rather
than a name:

- The value the release returns is its own localization table's entry, for the running language. It is
  not an English name that is the same everywhere, and there is no reading of it that is right for
  every device.
- The host offers no oracle. `dlopen("/System/Library/Frameworks/HomeKit.framework/HomeKit")` on
  macOS 27.0 reports the framework "not in dyld cache", and the framework's directory holds only
  `PlugIns`; there is no copy of the binary and no header outside the SDK.
- No release this machine holds ships a HomeKit resource bundle the port could read the strings from:
  the caches the constants were read from carry the framework's code and its constants, and the
  localized descriptions were not located in them by a method that could pair a description with the
  type it belongs to, which is what pairing them safely needs.

So the property is registered `absent`. Writing an English name into the port would be a value that
looks right, describes something, and is not what any release ships — the exact failure the ledger
calls a silent fake. An application that asks for the description of a category on this port gets
`respondsToSelector:` answering NO, which is the honest answer, and it can still compare category
types, which is what the UUIDs are for.
