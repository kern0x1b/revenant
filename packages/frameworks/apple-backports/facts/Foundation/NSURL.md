# NSURL, the file URLs of iOS 7 and iOS 9

Source: the host's own Foundation, asked directly and through the differential run of
`tests/backports/host/foundation2/run.sh`, which holds the backport to the same answers under the
records `url.fileSystem.*`, `url.representation.*`, `url.dataRepresentation.*`, `url.relativePath.*`,
`url.relativeDirectory` and `url.resourceCache`.

## Deciding directory or file without being told

`-initFileURLWithPath:relativeToURL:` and `+fileURLWithPath:relativeToURL:` are the two that have to
decide for themselves, and they decide by asking the URL they are about to answer for its own
`NSURLIsDirectoryKey`. Not by expanding the path and looking it up: the release says so itself, because
against a base that is not a file URL it logs

    CFURLCopyResourcePropertyForKey failed because it was passed a URL which has no scheme

and answers a file URL. Everything else follows from that one call:

| asked, against a directory that holds `folder/`, `folder/inner/`, `file.txt`, `~/inner/` and a link | answered |
|---|---|
| `folder` | `folder/`, a directory |
| `folder/` | `folder/`, a directory - the trailing slash is not what decides |
| `file.txt` | `file.txt`, a file |
| `missing` | `missing`, a file |
| `link`, a symbolic link to `folder` | `link`, a **file** |
| `link/inner` | `link/inner/`, a directory |
| `broken`, a link to nothing | `broken`, a file |
| `~/inner`, where `~` is a real directory of that name | `~/inner/`, a directory |
| `folder/../folder` | `folder/../folder/`, a directory, `..` and all |

Two of these are what a path lookup would get wrong. A symbolic link to a directory answers **file**,
which is the property's own reading of the last component and not `stat`'s; a link in the middle of the
path is followed all the same. And the tilde is a character like any other: `~/Library` answers a file
even where the home directory holds `Library`, because nothing expands it. What the base gives is only
the directory the name is resolved against - `lib` is a directory beside `file:///usr/` and a file beside
`file:///usr/bin/` - and a base that is not a file URL, or none at all with a relative name that the
working directory does not hold, ends at a file.

The path is carried into the URL untouched in every case: `~/tilde` stays `~/tilde`, `/usr/bin/../lib`
keeps its `..`, and only the trailing slash of a directory is added or dropped.

An empty path answers nil, with or without a base.

## The file system representation

`-fileSystemRepresentation` is the absolute URL's POSIX path in the file system's own bytes, which are
decomposed: `/tmp/a b/ä` comes back as `2f 74 6d 70 2f 61 20 62 2f 61 cc 88`, an `a` and a combining
diaeresis, and `file:///na%CC%88ive` stays decomposed as it was written. A percent escape that is not a
path character is left standing as text - `file:///a/%00b` gives `/a/%00b` and `file:///%C3%A4%2F` gives
`/ä%2F` - and a host is dropped: `file://host/x` gives `/x`. A URL with no file path at all - `file:`,
`mailto:x@y`, `data:,hello` - answers NULL.

The buffer belongs to no one: two calls on the same URL inside one autorelease pool answer two different
pointers, and after the pool drains the next call is free to answer the first pointer again. It is the
caller's business to copy it before the pool drains.

`-getFileSystemRepresentation:maxLength:` wants room for the terminating zero as well: `/p q/r` is seven
bytes and fails at six, `/x` fails at two and fits at three. When it does not fit it answers NO and
leaves the buffer as it found it.

`-initFileURLWithFileSystemRepresentation:isDirectory:relativeToURL:` takes the bytes as they come. An
empty path with no base answers nil, and with a base answers the base itself; a relative path with no
base is taken against the working directory.

## The data representation

`-dataRepresentation` answers the bytes of the URL's own relative part, not of the absolute URL: the URL
made from `relative/path` against `http://base/dir/` answers `relative/path` again. They are the bytes
the URL was made from and not the escaped text - a URL made from the raw UTF-8 of `http://host/ä` reads
back those same raw bytes although its `relativeString` is `http://host/%C3%A4`. Empty data answers empty
data and, against a base that ends in a slash, a URL that has a directory path.

`+URLWithDataRepresentation:relativeToURL:` keeps the URL relative to its base and
`+absoluteURLWithDataRepresentation:relativeToURL:` resolves it. Both read the bytes as UTF-8 and fall
back to ISO Latin 1 when they are not: `68 74 74 70 3a 2f 2f 68 2f e4 ff` becomes
`http://h/%C3%A4%C3%BF`, and its data representation is those same eleven bytes again.
The fallback is ISO Latin 1 and not Windows 1252 - `80 9f` becomes `%C2%80%C2%9F` - and it takes the
whole data, not only the bytes that fail: `c3 a4 ff` becomes `%C3%83%C2%A4%C3%BF`.

On iOS 6 the same fallback happens - CFURL refuses those bytes as UTF-8 and takes them as ISO Latin 1 - and
the URL agrees with the current one in everything but its string. Its path is `/äÿ`, its query and
fragment stay escaped in ISO Latin 1 (`q=%FF`, `%E4`) as they do on the current release, its data
representation and its absolute URL's are the original bytes, and a path component appended to it gives
the same UTF-8 URL on both. What differs is the string: CFURL of iOS 6 escapes it in the encoding the URL
was read in, so `e4 ff` gives `http://h/%E4%FF` where the current release gives `http://h/%C3%A4%C3%BF`.
A later CFURL escapes that string in UTF-8 while it keeps the bytes in ISO Latin 1; iOS 6 has no public
way to make a URL like that, so the backport answers with the release's own URL and this string is where
it stays different. Measured with the same five inputs on macOS 27 and on iOS 6.0 in the emulator.

## The temporary resource value and the caches

`-setTemporaryResourceValue:forKey:` puts a value into the URL object's own cache, where
`-getResourceValue:forKey:error:` and `-resourceValuesForKeys:error:` then find it under any key name,
including one the system has never heard of. Three things about it are not obvious and were measured:

- a value of nil is stored as `NSNull`, not as nothing, so the key reads back as `<null>` rather than as
  a missing value.
- the cache belongs to the object, not to the path: `-copy` answers the very same object, so the copy
  sees the value, while a second URL built from the same path does not.
- `-removeCachedResourceValueForKey:` and `-removeAllCachedResourceValues` clear temporary values along
  with cached ones, and a key the file system can answer for itself - `NSURLIsDirectoryKey` - is simply
  read again afterwards.

`-getResourceValue:forKey:error:` answers YES for a key it has nothing for, leaving the value nil and the
error alone, so the answer to "is it there" is the value and not the return.

## The ubiquitous item keys

The six constants carry their own names as their values, which is how the release writes them:
`NSURLUbiquitousItemDownloadingStatusKey`, `NSURLUbiquitousItemDownloadingErrorKey`,
`NSURLUbiquitousItemUploadingErrorKey`, and the three statuses
`NSURLUbiquitousItemDownloadingStatusNotDownloaded`, `…Downloaded` and `…Current`. The release answers
none of them for a file of its own; they are there so that an application that names the key builds and
runs, and so that a status it reads compares equal to the one it was given.

## Security-scoped resources

`-startAccessingSecurityScopedResource` and `-stopAccessingSecurityScopedResource` (iOS 8) come with the document picker.
The release has no sandbox scope to open, so the start answers YES for every URL and the stop does nothing. The system
answers NO for a URL that is not security scoped, which an application sees only for a file it already owns; the port
answers YES so that code which reads a picked document only when the start succeeded reads it.
