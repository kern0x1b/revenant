# SafariServices on iOS 6: SSReadingList

`SSReadingList` (iOS 7) is what Telegram's `GalleryController.swift:1256` calls for "Add to Reading List". iOS 6 has no
SafariServices framework, but Safari has a Reading List, kept in `/var/mobile/Library/Safari/Bookmarks.db` and written through
the private `WebBookmarks.framework` (`WebReadingList`).

## What `src/SafariServices/SSReadingList.m` does

- `+defaultReadingList` returns the shared list, or `nil` when the release cannot add to the Reading List in this process, which is
  the case the SDK header documents: `WebBookmarks` does not load, `+[WebReadingList _isSupported]` answers no, or the process
  cannot read and write `Bookmarks.db` (`access(2)`, which a sandbox answers).
- `+supportsURL:` accepts `http` and `https`, in any case of letters, and nothing else, then asks `+[WebReadingList
  _isSupportedReadingListURL:]` too.
- `-addReadingListItemWithURL:title:previewText:error:` returns `NO` with `SSReadingListErrorDomain` and
  `SSReadingListErrorURLSchemeNotAllowed` for another scheme, and otherwise hands the item to `-[WebReadingList
  addReadingListItemWithURL:title:previewText:]` on the main thread and returns `YES`. The release saves a batch on a timer, so
  the item is in the list a fraction of a second later, not when the call returns.
- `SSReadingListErrorDomain` is `SSReadingListErrorDomain`; the value is recalled from Apple's error logs, not read from the
  framework.

## Measured on an iPhone 4S, iOS 6.1.3

`ReadingListProbe` (`tests/device_probe/reading_list_main.m`), launched through SpringBoard as user `mobile` from `/Applications`:

- The app is not sandboxed there: home is `/var/mobile`, and `Bookmarks.db` is readable and writable.
- `WebReadingList` takes `http` and `https` in any case and refuses `ftp`, `mailto`, `file`, `tel`, `data`, `javascript` and a
  string without a scheme; it cuts a title and a preview text at 140 characters.
- An item added once is found in a fresh `WebBookmarkCollection` with its title, preview text and address, between 0.1 and 0.3
  seconds later and not at once. The same address added twice stays one item. An item added from a background thread reaches the
  list, because the call is moved to the main thread.
- With writes to `/private/var/mobile/Library/Safari` denied in the process by `sandbox_init`, `+defaultReadingList` is `nil`.
- All 21 checks of the probe pass. The probe removes the items it adds, and the phone was left without them.

Not measured: an app in a container (installed from the App Store), whose sandbox profile this phone has no app to test.
`access(2)` is what answers there, and a denial gives `nil`.
