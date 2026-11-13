# DISPATCH_DATA_DESTRUCTOR_MUNMAP on iOS 6

iOS 7 added `_dispatch_data_destructor_munmap`, the sentinel `DISPATCH_DATA_DESTRUCTOR_MUNMAP` stands for, so that `dispatch_data_create` can unmap a buffer made with `mmap`. The iOS 6.1.3 libdispatch (taken out of the shared cache and read with `nm`, a byte dump and the disassembly) exports `__dispatch_data_destructor_free`, `__dispatch_data_destructor_none` and `__dispatch_data_destructor_vm_deallocate`, and keeps `_inline` local. Each is a four-byte pointer variable that holds the address of a 20-byte global block (`_NSConcreteGlobalBlock`). `dispatch_data_create` compares the destructor with them by identity. Any other block is copied and run on the queue when the data is disposed, and the block receives no argument, so a block cannot know which buffer it is to unmap.

The munmap sentinel is therefore two things on iOS 6: a missing symbol (a weak import is NULL, which `dispatch_data_create` reads as "copy the bytes" and the caller's mapping is never unmapped; a strong import stops the image) and, once the symbol exists, a block that unmaps nothing. Exporting the symbol alone would turn a visible failure into a silent leak.

## What the library does

`libSystemBackports.dylib` has three parts, in `src/libSystem/RevenantDispatchData.c`:

- `_dispatch_data_destructor_munmap` is a pointer variable to a global block, like the three of the release. It is `BACKPORT_IMPL(_dispatch_data_destructor_munmap)`, so the generated storage takes the release's value at load when the release exports one (iOS 7 and later) and the library's block when it does not.
- `dispatch_data_create` is a wrapper. When the destructor is the library's own block, it makes a block that captures the buffer and `round_page(size)` and calls `munmap(buffer, length)` once, and passes that block to the release's `dispatch_data_create`, which copies it and frees the copy with the data object. For any other destructor, including the release's own munmap sentinel on iOS 7 and later, it calls the release's function with the arguments it was given. The release's function is found once, with `dlsym` on the libSystem handle, under `dispatch_once`. A NULL buffer or a size of zero goes to the release's function with the same block: whatever it does for an empty buffer (the release returns the empty data, and runs the destructor on the queue or not) is the same as for the other destructors, and the block unmaps nothing when the buffer is NULL or the length zero.
- `___revenant_override_dispatch_data_create` is the override marker (`BACKPORT_OVERRIDES(dispatch_data_create)`). `dispatch_data_create` exists in the release, so no import of it would move to the library without the marker; with it, `revenant.rebind` moves the import of a named image to the wrapper (`docs/guides/toolchain/rebind.md`).

## Scope: who is affected, and who still leaks

Reaches the wrapper:

- A prebuilt image named in `revenant.rebind` (the reCAPTCHA Enterprise SDK is the case that asked for it): its imports of `_dispatch_data_destructor_munmap` and `_dispatch_data_create` both move to the library, so the sentinel it passes is the library's and the wrapper sees it.
- An application built with the Revenant toolchain that links `libSystemBackports.dylib` before libSystem: the link binds `_dispatch_data_create` to the library.

Keeps the release's function, and so the no-op block:

- An image bound to libSystem or libdispatch directly that is not named in `revenant.rebind` and does not link the library first. Such an image cannot have the sentinel's symbol either, since the release lacks it: a weak import is NULL (the caller's own guard decides, and without a guard the bytes are copied, no unmap) and a strong one stops the image at load. So this class has no caller that passes the sentinel and gets a no-op block, except through a function pointer to `dispatch_data_create` taken before the library loaded.
- Swift code: `DispatchData.Deallocator.unmap` goes to `_swift_dispatch_data_destructor_munmap()` of `libswiftDispatch`, which the overlay patch `the-overlay-of-dispatch-unmaps-its-data-where-a-release-before-7-has-none` makes `NULL` where the symbol is NULL, and then builds its own block that unmaps the range. If `libswiftDispatch` is bound to the library, the check is no longer NULL, the overlay passes the sentinel, and the wrapper unmaps (once; the overlay's own block is not made on that path). That image must have its `dispatch_data_create` import moved too, which `revenant.rebind` does, and an image that binds the sentinel to the library and `dispatch_data_create` to libdispatch would leak. The build does not do that: both imports of a named image move together, and an unnamed `libswiftDispatch` binds neither.

## Why no interposing

`__DATA,__interpose` would have reached every image, but dyld 6.1.3 registers the tuples of the images in `DYLD_INSERT_LIBRARIES` only: in `dyld::_main` the one virtual call of `ImageLoader::registerInterposing` is inside the loop over `sAllImages[1 .. sInsertedDylibCount]`. The emulator measurement in `docs/explanation/backports-open-members.md` agrees (a launch-linked tuple does not redirect the executable's calls). Rewriting `__la_symbol_ptr` from a constructor would patch every image and miss function pointers taken earlier, so the library does not.

## Cost

One `dispatch_once_f` check and one pointer comparison before the release's call. Measured on the iPhone 4S (iOS 6.1.3), best of five rounds of 100,000 calls that copy 16 bytes and release the data: the release's function 2,561 ns and the wrapper 2,603 ns per call (an earlier run: 2,755 and 2,846), so the wrapper adds about 40 to 90 ns, 2 to 3 percent. The host figure is 44 and 45 ns.

## Device result

On the iPhone 4S with iOS 6.1.3 (`libsystem_dispatch_device_test.lua`, the built library and the fixture linked against it): 33 checks passed. Data made over the middle of three mapped pages with the public `_dispatch_data_destructor_munmap`, which is bound and not NULL, is mapped while the data lives; after the release the range answers `ENOMEM` from `msync`, and the pages before and after it are still mapped, so exactly the rounded range is unmapped. The empty data, the custom, free and NULL destructors behave as on the host.

## Tests

`frameworks/Backports/tests/libsystem_dispatch/main.c`, built from the library's sources by `libsystem_dispatch_test.lua` on the host: data made over the middle page of three mapped pages with the library's sentinel is mapped while the data lives, and unmapped (`msync` answers `ENOMEM`) once it is released, with the pages before and after untouched; the empty data (NULL buffer, zero size) is returned; a custom destructor runs once, the free destructor and a NULL destructor pass through; and the macOS libdispatch's own sentinel passes through the wrapper and unmaps the same way. On the iPhone 4S the same fixture is linked against the built library and the public symbols are used, so `&_dispatch_data_destructor_munmap` is bound and not NULL, which is what makes the overlay's check pass, and the data made with it is unmapped. `toolchain/tests/addon/rebind_test.lua` checks the marker: an import the release exports moves to a provider that carries the marker, stays when the provider has no marker or the marker of another symbol, and the rebound image passes the import check.
