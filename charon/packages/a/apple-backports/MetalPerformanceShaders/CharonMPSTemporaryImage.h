// CharonMPSTemporaryImage.h - the allocator MPSImage.h:930's +defaultAllocator answers with.
//
// WHY IT IS ITS OWN FILE, and this is measured rather than tidiness. The allocator is a class, and a
// class is an _OBJC_CLASS_$_ symbol, which no release carries. Defining it beside MPSTemporaryImage -
// which IS release API, first appearing at 10.0.1 - made tools/release-split.lua read that one object
// as spanning two releases and refuse it:
//
//     MPSImageElements10.o  MIXED-RELEASES  10.0.1,none
//
// So the allocator lives here, in a file that exports ONE C function whose name begins `charon_`, which
// release-split's internal() excludes from a file's release set for exactly this reason. That is the
// same shape as packages/a/apple-backports/UIKit/UIViewController+DocumentMenu.m, and charon/AGENTS.md
// gives the reason it has to be this shape: an object is placed by the release whose API it defines, so
// a symbol in an object of one release is left out of the bands where that release is not carried, and
// a cross-object reference to it is Undefined symbols in those bands only.
//
// The class itself is private to this pair of files: it is not declared by any SDK header under the
// name MPSImageAllocator or any other, so it carries no registry row of its own - it is the object
// behind a method the release does declare, not API in its place.

#import "CharonMPS.h"

// The one well known MPSImageAllocator that makes MPSTemporaryImages, MPSImage.h:930. A process-wide
// singleton, because the release's own two allocators are process-wide caches and a caller comparing
// allocators by identity would see the same object the release shows.
id<MPSImageAllocator> CharonMPSTemporaryImageDefaultAllocator(void);
