# UIPrinterPickerController, iOS 8

Introduced in iOS 8.0 as the printer picker: a sheet (on the phone) or a popover (on the pad) that lists the printers
the system finds and completes with the one the user chooses. The SDK 16.4 header is the contract
(`UIPrinterPickerController.h`): `+printerPickerControllerWithInitiallySelectedPrinter:`, `selectedPrinter`, `delegate`,
`presentAnimated:completionHandler:` (iPhone), `presentFromRect:inView:animated:completionHandler:` and
`presentFromBarButtonItem:animated:completionHandler:` (iPad), `dismissAnimated:`, and the delegate protocol
`UIPrinterPickerControllerDelegate` (seven optional methods, all 8.0).

The release (6.1.3) has no printer picker. The port builds one from what the release has: an AirPrint printer advertises
over Bonjour as `_ipp._tcp` with the `_universal` subtype, so the picker browses `_universal._sub._ipp._tcp.` in `local.`
with `NSNetServiceBrowser` (public in Foundation since iOS 2). Each service it finds is resolved (10 s); the picker lists
the resolved ones in a `UITableView` inside a `UINavigationController`, under the title "Printers" with a Cancel button.

## The host's answers, measured on Mac Catalyst

The probe is a plain command-line process, with no application and no window (a `UIWindow` cannot be created in it).
The differential in `tests/backports/host/uikit-printer/` holds the lines (the `open:picker-*` lines are printed from
both sides, not compared):

- The class exists.
- `+printerPickerControllerWithInitiallySelectedPrinter:` answers a new object on each call (not identical).
- With an initial printer, `selectedPrinter` is non-nil, but it is not that printer: it is a different object whose URL
  is nil. With a nil initial printer, `selectedPrinter` is non-nil too, with a nil URL.
- `presentAnimated:completionHandler:` and `presentFromRect:inView:animated:completionHandler:` answer YES and run the
  completion before they return, with the same controller, `userDidSelect` YES and a nil error. No picker is shown.
  That is a placeholder selection: a printer with no URL, chosen without the user.
- After that completion, a call to `dismissAnimated:` runs nothing more.

## What the port does

- `selectedPrinter` is the printer the picker was made with (the same object), and nil when it was made with nil. The
  host's placeholder is not copied: it is a printer with no URL, chosen without a user. This is the difference named
  above.
- A listed printer is `+printerWithURL:` with `ipp://<host>:<port>/<rp>`, from the resolved service: the host is the
  service's host name without its trailing dot, the port its port, and the path the `rp` TXT key (leading slashes
  removed, percent-escaped). A service with no `rp` gives `ipp://<host>:<port>/`. Its descriptive properties are the
  UIPrinter host defaults (`displayName` is the empty string); the list shows the service name.
- `shouldShowPrinter:` filters each printer before it is listed. It is called on the main queue (the header allows
  any thread).
- A selection calls `printerPickerControllerDidSelectPrinter:`, takes the picker down, and runs the completion once with
  `userDidSelect` YES and a nil error. Cancel, a tap outside a popover, and `dismissAnimated:` run it with `userDidSelect`
  NO. A browse the browser reports as failed runs it with `userDidSelect` NO and an `NSError` in
  `NSNetServicesErrorDomain`, with the browser's code. In a scratch probe on the host's process the browser reported
  a failure before `searchForServicesOfType:` returned; the differential does not reach that path, since its
  presentation fails first.
- The phone presents modally on the parent view controller (`printerPickerControllerParentViewController:`, else the
  key window's root, topmost presented controller). The pad's rect and bar-item variants use a `UIPopoverController`.
  On the phone the two pad variants present as `presentAnimated:` does, since a popover does not exist there.
- The browse starts only once the picker is presented, and stops when it is taken down. With no service found the list
  stays empty.
- `presentAnimated:` and the pad variants answer NO, and run nothing, when there is no parent view controller to present
  from (no key window and no delegate parent) or the presentation does not take.

## Open

- The host's placeholder selection is not matched (above). Listed as `open:` lines in the differential.
- In the differential's process, which has no window, the port's presentation answers NO and runs no completion, where
  the host answers YES and runs the placeholder completion. The port's presentation with a window is not run by the
  differential.
- The 6.1.3 emulator check, partly measured (`tests/backports/emulate/uikitprinter/run-app.sh`, iPhone4,1 at 6.1.3): the
  picker presents over the key window (present YES, the delegate's will and did present), and it dismisses with
  `userDidSelect` NO and `NSNetServicesErrorDomain` -72004 when the browse fails. The emulator's guest browse fails for
  a bare `NSNetServiceBrowser` the same way (the control in the same application, "did not search"), so the failure is the
  guest's Bonjour, not the port's. What the emulator cannot show: the list. The picker dismisses before any list
  appears, so "lists nothing when no service is found" and Cancel (`userDidSelect` NO by a tap) are not measured here.
- The Bonjour browse is not measured on the host against a real AirPrint printer; the host's own Bonjour answers are not
  compared.
- The `printerPickerControllerDidPresent:` delegate call on the pad runs right after the popover is asked to appear,
  not when its animation ends; UIPopoverController gives no completion for that.

## Device

The 6.1.3 emulator run is the one in the open list above (the presentation and the browse-failure dismissal). Not run
on a hardware device.
