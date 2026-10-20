# The radio access technology, iOS 7.0

iOS 7.0 gave `CTTelephonyNetworkInfo` the property `currentRadioAccessTechnology`, which answers one of
eleven strings for the kind of radio network the phone is on (GPRS, EDGE, WCDMA, HSDPA, HSUPA, the CDMA
family, eHRPD and LTE) or nil, and a notification name, `CTRadioAccessTechnologyDidChangeNotification`, for a change.

Source: CoreTelephony of the arm64 shared cache of iOS 12.0 - the constants `_CTRadioAccessTechnology...`
at `0x1b040ca68` to `0x1b040caf8` and `-[CTTelephonyNetworkInfo currentRadioAccessTechnology]` at `0x183d8d674`;
an iPhone 4S and an iPad 2 running 6.1.3, and the iOS 6.0 emulator, for what the release exports and answers.

## What it is

Each constant is a string equal to its own name, and there are two names for the WCDMA one in iOS 12,
`_CTRadioAccessTechnologyWCDMA` and `_CTRadioAccessTechnologyWCMDA`, which both hold
`CTRadioAccessTechnologyWCDMA`. The property reads the technology that iOS 12 keeps for the data service of the phone and
answers nil where there is none.

## Where iOS 6 differs

iOS 6.0 has none of these names. iOS 6.1.3 exports every one of them but `CTRadioAccessTechnologyWCDMA`, and keeps the
technology in a class of its own, `CTRadioAccessTechnology`, whose `-radioAccessTechnology` a `CTTelephonyNetworkInfo`
gives through its own `-radioAccessTechnology`. The string it holds is spelled as iOS 12 spells its second WCDMA name
in the constant, not its value: on the iPhone 4S on 3G it was `CTRadioAccessTechnologyWCMDA`.

So the property is that string, with the misspelling given the value iOS 7 gives WCDMA, and nil where the release has no such
class, which iOS 6.0 has not, or the class holds no technology. The constants are carried under their own names, WCDMA
included; on 6.1.3 the release's own copy of the others has the same value. The notification name is carried as a name. That
the release posts it was not verified.

`serviceCurrentRadioAccessTechnology`, the per-service dictionary of iOS 12, `serviceSubscriberCellularProviders`, the delegate
of iOS 13, `CTCellularData` and the two 5G names are absent: iOS 6 has one radio and one service.
