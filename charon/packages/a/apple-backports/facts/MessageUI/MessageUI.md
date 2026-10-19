# MessageUI on the release's own compose controllers

Everything here is a question asked of the release and answered from it. The release's own
`MFMessageComposeViewController` and `MFMailComposeViewController`, read out of the armv7 6.1.3
cache's ObjC metadata with `objc.binary_inventory`. The list below is the class's own selectors, not
the ones it inherits from `UINavigationController` and `NSObject`, which is what the two facts this
delivery rests on turn on:

    MFMessageComposeViewController  (its own; it also inherits UIViewController's and NSObject's)
      -body  -dealloc  -initWithNibName:bundle:  -messageComposeDelegate  -recipients
      -setBody:  -setMessageComposeDelegate:  -setModalPresentationStyle:  -setRecipients:
      -smsComposeControllerCancelled:  -smsComposeControllerSendStarted:  -viewWillAppear:
      -automaticallyForwardAppearanceAndRotationMethodsToChildViewControllers
      +canSendText  +initialize  +-_canSendText  +-_serviceAvailabilityChanged:  +-_setupAccountMonitor
      +-_startListeningForAvailabilityNotifications  +-_updateServiceAvailability
    MFMailComposeViewController  (its own; it also inherits UIViewController's and NSObject's)
      +canSendMail  +hasAutosavedMessageWithIdentifier:  +maximumAttachmentSize
      +removeAutosavedMessageWithIdentifier:
      -addAttachmentData:mimeType:fileName:  -autosaveWithHandler:  -dealloc
      -finalizeCompositionValues  -initWithNibName:bundle:  -initWithURL:  -mailComposeDelegate
      -recoverAutosavedMessageWithIdentifier:  -requestFramesForAttachmentsWithIdentifiers:resultHandler:
      -setAutorotationDelegate:  -setBccRecipients:  -setCcRecipients:  -setContentVisible:
      -setKeyboardVisible:  -setMailComposeDelegate:  -setMessageBody:isHTML:  -setSubject:
      -setToRecipients:  -shouldAutorotateToInterfaceOrientation:  -viewWillAppear:
      -addSetupAnimationBlock:
      -automaticallyForwardAppearanceAndRotationMethodsToChildViewControllers
      -__viewControllerWillBePresented:  -_addAttachmentData:mimeType:fileName:  -_internalViewController
      -_validEmailAddressesFromArray:

Between the two lists is the whole of what the two composers of this release can do, and it is what
the three class methods are asked about rather than a table written here:

- `+canSendSubject` is YES exactly when the release's controller has `-setSubject:`. It does not, so
  the answer is NO - which is also the truth about iOS 6, whose SMS composer has no subject field.
- `+canSendAttachments` is YES exactly when it has `-addAttachmentData:typeIdentifier:filename:`. It
  does not, so NO - also the truth: iOS 6's Messages sends a text message and has no path to send an
  attachment with.
- `+isSupportedAttachmentUTI:` is the first of those *and* a check that the release's own
  MobileCoreServices store knows the identifier, through `UTTypeConformsTo` against `public.data`
  (public from iOS 3 to 14). On this release the first half is already NO, so the answer is NO; on a
  release whose composer can take attachments the second half is a real lookup in that release's own
  type store, not a list in this file.

The two add methods record what they were given when the composer can take it and answer NO when it
cannot, which is the header's own answer for an attachment that will not go in. `-attachments` then
reports the controller's real contents, so on this release it is empty because nothing can be put in
it - a report about the controller, not a placeholder.

**The two keys of the array are the release's own constants, and this release has neither.**
`MFMessageComposeViewControllerAttachmentURL` and
`MFMessageComposeViewControllerAttachmentAlternateFilename` are absent from the armv7 6.1.3 cache's
symbol table - measured with `dump-cache.lua` over the whole cache, where both names do not appear at
all - so an array the port built would carry keys of its own making and an application reading
`MFMessageComposeViewControllerAttachmentURL` out of it would get nil. The gate's first run of this
delivery caught the reference at link time ("Undefined symbols ... `_CGRectGetWidth`, `_CGRectZero`"
and, had it got that far, these two). So both keys are asked of the release at run time through
`dlsym`, an attachment is not recorded unless the release really has both, and `-attachments` builds
its dictionaries with the release's own strings. On this release the answer is an empty array for two
independent reasons - the composer cannot take an attachment, and the keys do not exist - and both are
true.

## The three that are not carried at all

`-disableUserAttachments`, `subject` and `-setUPIVerificationCodeSendCompletion:` are registry entries
with status `absent`, and the port carries no code for any of them. The reason is the same in each
case and it is not "doing nothing is safe":

- `-disableUserAttachments` hides affordances the iOS 7 compose sheet grew. This release's sheet has
  none, so there is nothing to disable and the postcondition already holds.
- `subject` names a field the release's composer does not have, and its Messages sends no MMS, so a
  subject can be neither shown to the sender nor transmitted. A value kept here would be read back to
  the application and never sent - the worst of both, and exactly the "silently different answer" that
  COORDINATION.md §2 calls the most dangerous outcome there is.
- `-setUPIVerificationCodeSendCompletion:` belongs to the one-time-code detection in the system
  Messages app, a service that arrived with iOS 17. The block reports whether a code the user pasted
  was sent, so a block the port kept would be a completion nothing could ever call.

Carrying a selector for any of them would mean storing a value nothing can act on, which is the silent
fake. Not carrying it is the port's own answer for a member of a release class the release cannot
honour: `absent`, the accessor not declared, `respondsToSelector:` answering NO, and an unchecked call
a crash the application avoids by asking `+canSendSubject` / `+canSendAttachments` - which the port
does carry, and which answer NO for the same measured reason. The port has 589 absent methods and 727
absent properties of this shape already; `registry/MediaPlayer/absent_MediaPlayer.json` is the
largest.

## The two collaboration factories

`-[MFMessageComposeViewController insertCollaborationItemProvider:]` answers NO and
`-[MFMailComposeViewController insertCollaborationItemProvider:completionHandler:]` calls its
completion with NO: the document interaction that draws a collaboration row came later, and neither
composer of this release has a view to insert one into. `NSItemProvider` itself is real - the port
carries it (`registry/Foundation/base.json`, `facts/Foundation/NSItemProvider.md`) - so the argument
is a real object; there is simply nowhere to put it.

## `message`, and the class it needed

`MFMessageComposeViewController.message` was the one row of this framework that could not be answered
while `MSMessage` was a row of the *Messages* framework the port did not carry: its contract is a value
property, and the value is an `MSMessage`. The Messages delivery carries the four classes that value
needs - `MSMessage`, `MSMessageLayout`, `MSMessageTemplateLayout`, `MSSession` - so the row is
answered now (`registry/Messages/ios10.json`, `facts/Messages/MSMessage.md`): copied in, copied out,
and a fresh message carrying the composer's own body when none was set.

What it is not is *interactive*. iOS 6.1.3's Messages sends a text message and has no iMessage, no
interactive bubble and no URL payload, and the release's own `MFMessageComposeViewController` has no
notion of a message at all - measured in its armv7 6.1.3 ObjC metadata. So the message's session, URL,
layout and captions travel with it and are never drawn. That is the same answer `+canSendSubject` and
`+canSendAttachments` give, and for the same measured reason.

## Not measured against a host

Neither compose controller exists on the host, so there is no differential for this framework; both
are iOS-only classes with no macOS counterpart under Mac Catalyst. The measurement here is the
release's own metadata, quoted above.
