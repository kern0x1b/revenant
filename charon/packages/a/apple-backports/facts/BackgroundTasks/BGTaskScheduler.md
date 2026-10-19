# BackgroundTasks, iOS 13

Introduced in iOS 13: an application registers a launch handler per task identifier and submits requests - a short refresh or
a longer processing task - and the system launches it in the background when conditions allow.

Source: the SDK headers of BackgroundTasks and what they document; the host has no such framework, so there is no oracle to
compare against and the device test holds the port to the headers. The shared caches of iOS 6.0 and 7.0 have none of it.

## What the port does

- `BGTaskScheduler.sharedScheduler` is one object. `-registerForTaskWithIdentifier:usingQueue:launchHandler:` answers NO for
  an identifier that `BGTaskSchedulerPermittedIdentifiers` of the Info.plist does not list, and YES for one it lists; it
  raises `NSInternalInconsistencyException` for a second handler for the same identifier and once the application has
  finished launching, as the documentation says it is an error.
- `-submitTaskRequest:error:` answers NO with `BGTaskSchedulerErrorDomain` code 3 (not permitted) when the identifier is not
  permitted or the background mode of the request (`fetch` for a refresh, `processing` for a processing task) is not in
  `UIBackgroundModes`, and otherwise code 1 (unavailable), the error the header gives for scheduling that is not available
  to the application.
- The pending requests are always empty and cancelling does nothing, since nothing is ever accepted.
- The requests hold their identifier, earliest begin date and, for processing, the network and external power switches, and
  copy. The task classes are present, hold an identifier and an expiration handler that `-setTaskCompletedWithSuccess:`
  clears; no task is ever created.

## What it cannot do

iOS 6 launches an application in the background only for the few modes it has - audio, location, VoIP, newsstand - and has
no scheduler that runs an application for a refresh or processing task. So a launch handler is kept and never called, and a
request is never accepted: an application that submits one finds out from the error and carries on as it does where
Background App Refresh is off.
