# Directory attribute listing (getdirentriesattr, 222)

The emulator answers `getdirentriesattr` in `emulator/src/kernel/bsd/filesystem.cpp` (`case 222`), packing each entry with
`hfs::MetadataProvider::pack_attributes` and sizing batches with `MetadataProvider::fixed_block_size`. The source it follows is
XNU `xnu-2050.18.24`, fetched into `~/.revenant/cache/photos-alassets/xnu` as `bsd/vfs/vfs_syscalls.c`, `bsd/hfs/hfs_attrlist.c`,
`bsd/hfs/hfs.h`, `bsd/hfs/hfs_catalog.h` and `bsd/sys/attr.h`.

## Matched

- The syscall, `getdirentriesattr` (`vfs_syscalls.c` 7179–7300). `count` is read as the number requested and written back as the
  number packed (`*count` from `VNOP_READDIRATTR`). `basep` is written with the offset at the start of the call (`loff`,
  line 7242), not with the last entry. The file offset is advanced to the position after the packed entries (line 7270). The return
  value is `eofflag`, 0 or 1 (`vfs_syscalls.c` 7279, `*retval = eofflag`).
- A non-directory is `EINVAL` (`vfs_syscalls.c` 7227). A descriptor that is not open is `EBADF`.
- The attribute request. Volume attributes and any `bitmapcount` other than 5 are `EINVAL`
  (`hfs_attrlist.c` 126–135, `hfs_vnop_readdirattr`). The authorization check is at `vfs_syscalls.c` 7257.
- Options. Only `FSOPT_NOFOLLOW` (0x1) and `FSOPT_NOINMEMUPDATE` (0x2) are accepted; any other bit is `EINVAL`
  (`hfs_attrlist.c` 126; `attr.h` 46–50). `FSOPT_PACK_INVAL_ATTRS` (0x8) is refused on this path.
- `.` and `..` are not returned (`hfs_attrlist.c` 78, the header comment of `hfs_vnop_readdirattr`).
- `count` of 0, or a buffer of 0 bytes, is `EINVAL` (`hfs_attrlist.c` 126, `maxcount <= 0`).
- The batch size. A call packs at most `buffer / (fixed block + 22)` entries, where the fixed block is the 4-byte length plus
  the common, directory and file attributes requested, and 22 is `HFS_AVERAGE_NAME_SIZE` (`hfs_attrlist.c` 205, `hfs.h` 515).
  If that is below one, the call is `EINVAL` (`hfs_attrlist.c` 208).
- The stop rules. The packing loop stops at the first record that does not fit, after a packed entry when the count is used
  up, or when the remaining buffer is less than the batch estimate (`hfs_attrlist.c` 336–339).
- The end-of-directory rule. `eof` is set when every entry in the directory was packed in this call (line 346), when the start
  is already past the last entry (line 169), and when nothing was packed though entries remain (the `else` at the end of
  `hfs_vnop_readdirattr`).

## Not matched

- The batch cap `MAXCATENTRIES` (`hfs_catalog.h` 197), which bounds the catalog read per call. The emulator packs up to the
  batch estimate without that cap, so a directory bigger than the cap is read in one batch here and in several batches on the
  device. The number of entries per call can therefore differ for large directories.
- `newstate`. XNU writes the HFS directory change count (`c_dirchangecnt`, read at `hfs_attrlist.c` 164, written at 397). The emulator writes the number
  of entries in the listing. Callers that compare `newstate` between calls to notice a change see a change only when the number
  of entries changes.
- The entry order. HFS returns catalog order; the emulator returns names sorted as bytes.
- The authorization. XNU checks `LIST_DIRECTORY` and `SEARCH` with `vnode_authorize` (`vfs_syscalls.c` 7257) and fails
  the call on a denial. The emulator has no per-directory authorization here.
- `FSOPT_NOFOLLOW`. It is accepted and not applied: each entry's attributes are read without following a symbolic link.
- The file offset encoding. XNU stores an index and a tag in the offset (`hfs_attrlist.c` 166–168); the emulator stores the
  index alone, so the offsets it returns are not the offsets the device returns.
