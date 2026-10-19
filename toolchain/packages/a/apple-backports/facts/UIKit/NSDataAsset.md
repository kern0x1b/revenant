# NSDataAsset, iOS 9

Introduced in iOS 9: the data of a data set of an application's asset catalogue - a file the application keeps in `Assets.xcassets`
to read as data - found by name.

Source: the host's own UIKit. The `nsdataasset` group of `tests/backports/host/uikit2/run.sh` compiles the port with its names changed
next to the system's class and compares them on a catalogue an application was built with (`CHARON_DATA_ASSET_CATALOG`; the one
of Provenance, Xcode 26, CoreUI 970, was read: the data set matches the system's to the byte, in its type and its name) and on a
small catalogue the tests write (by a script since removed) for the parts the system will not read. `device/nsdataasset.m`
reads that catalogue on the iPhone 4S.

## Why the port reads the catalogue itself

iOS 6 has no CoreUI. `dlopen` of the framework finds nothing, there is no `CUICatalog`, and `+[UIImage imageNamed:]` finds no image in a
compiled `Assets.car`; the compiled catalogue is what an application built with a recent Xcode carries, so the port reads it. A
catalogue is a BOM store: the tree of facets maps a name to the identifier of its set, the tree of renditions holds the sets by a
key of attributes, and a data set is a rendition whose payload is the raw bytes, with its type in the list of tagged values before
it. The port walks the trees, finds the renditions of the identifier and takes the one whose idiom is the device's, or universal,
and whose scale is the screen's.

## What the port does as the system does

A name that is not in the catalogue, in another case, or empty, and a missing bundle, give no asset; no name raises
`NSInternalInconsistencyException` with the system's words. The type identifier is the one the catalogue holds, and `public.data` for
a set with none. An asset copies as itself and holds one immutable data, and describes itself as the system's does.

## What it cannot do

A data set the compiler stored compressed is not read: the compressions the catalogue names are the release's neither, and the port
gives no asset for it, as for a name that is not there. The catalogue Xcode builds for an application leaves small data sets
uncompressed, as Provenance's is. The choice among the variants of one set by the traits the system reads - dark, size class,
language - is the idiom and the scale only. A catalogue a newer Xcode writes in a layout the walk does not know is read as far as the
trees can be followed and then gives nothing.
