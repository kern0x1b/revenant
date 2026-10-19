// The TipKit differential probe: the values both modules answer with for the same inputs, one per
// line. Only the members both spellings have; the rest is in README.md with the shape differences.
import Foundation
#if PORT
import CharonTipKit
#else
import TipKit
#endif

func line(_ name: String, _ value: Any) { print("\(name)\t\(value)") }

// the life of a tip
line("status.pending", "\(Tips.Status.pending)")
line("status.available", "\(Tips.Status.available)")
line("status.invalidated", "\(Tips.Status.invalidated(.tipClosed))")
line("status.equal", Tips.Status.available == Tips.Status.available)
line("status.differs", Tips.Status.available == Tips.Status.pending)
line("invalidation.actionPerformed", "\(Tips.InvalidationReason.actionPerformed)")
line("invalidation.displayCountExceeded", "\(Tips.InvalidationReason.displayCountExceeded)")
line("invalidation.displayDurationExceeded", "\(Tips.InvalidationReason.displayDurationExceeded)")
line("invalidation.tipClosed", "\(Tips.InvalidationReason.tipClosed)")
line("invalidation.equal", Tips.InvalidationReason.tipClosed == Tips.InvalidationReason.tipClosed)
line("invalidation.differs", Tips.InvalidationReason.tipClosed == Tips.InvalidationReason.actionPerformed)

// the group
line("group.priority.firstAvailable", "\(TipGroup.Priority.firstAvailable)")
line("group.priority.ordered", "\(TipGroup.Priority.ordered)")
line("group.priority.equal", TipGroup.Priority.ordered == TipGroup.Priority.ordered)
line("group.priority.differs", TipGroup.Priority.ordered == TipGroup.Priority.firstAvailable)

// the time ranges a rule reads over
line("range.minute.hour", "\(Tips.DonationTimeRange.minute == Tips.DonationTimeRange.hour)")
line("range.minute.minutes1", "\(Tips.DonationTimeRange.minute == Tips.DonationTimeRange.minutes(1))")
line("range.days3.itself", "\(Tips.DonationTimeRange.days(3) == Tips.DonationTimeRange.days(3))")
line("range.days3.week", "\(Tips.DonationTimeRange.days(3) == Tips.DonationTimeRange.week)")
line("range.hours5.minutes300", "\(Tips.DonationTimeRange.hours(5) == Tips.DonationTimeRange.minutes(300))")
line("range.encoded", String(data: try! JSONEncoder().encode(Tips.DonationTimeRange.days(2)), encoding: .utf8)?.isEmpty == false)

// the configuration: the display frequency, the container, the location
line("frequency.immediate.hourly", "\(Tips.ConfigurationOption.DisplayFrequency.immediate == Tips.ConfigurationOption.DisplayFrequency.hourly)")
line("frequency.daily.daily", "\(Tips.ConfigurationOption.DisplayFrequency.daily == Tips.ConfigurationOption.DisplayFrequency.daily)")
line("frequency.weekly.weekly", "\(Tips.ConfigurationOption.DisplayFrequency.weekly == Tips.ConfigurationOption.DisplayFrequency.weekly)")
line("frequency.monthly.daily", "\(Tips.ConfigurationOption.DisplayFrequency.monthly == Tips.ConfigurationOption.DisplayFrequency.daily)")
line("container.automatic", "\(Tips.ConfigurationOption.CloudKitContainer.automatic == Tips.ConfigurationOption.CloudKitContainer.automatic)")
line("container.named", Tips.ConfigurationOption.CloudKitContainer.named("g") == Tips.ConfigurationOption.CloudKitContainer.named("g"))
line("container.named.differs", Tips.ConfigurationOption.CloudKitContainer.named("g") == Tips.ConfigurationOption.CloudKitContainer.named("h"))
line("location.applicationDefault", Tips.ConfigurationOption.DatastoreLocation.applicationDefault == Tips.ConfigurationOption.DatastoreLocation.applicationDefault)
let gc = try! Tips.ConfigurationOption.DatastoreLocation.groupContainer(identifier: "g")
line("location.groupContainer", gc == (try! Tips.ConfigurationOption.DatastoreLocation.groupContainer(identifier: "g")))
let loc = Tips.ConfigurationOption.DatastoreLocation.url(URL(fileURLWithPath: "/tmp/tips"))
line("location.url", loc == Tips.ConfigurationOption.DatastoreLocation.url(URL(fileURLWithPath: "/tmp/tips")))
// the errors
line("error.invalidPredicateValueType", TipKitError.invalidPredicateValueType.description)
line("error.missingGroupContainerEntitlements", TipKitError.missingGroupContainerEntitlements.description)
line("error.tipsDatastoreAlreadyConfigured", TipKitError.tipsDatastoreAlreadyConfigured.description)
line("error.errorDescription", TipKitError.invalidPredicateValueType.errorDescription ?? "<nil>")
line("error.hashEqual", TipKitError.invalidPredicateValueType == TipKitError.invalidPredicateValueType)
line("error.hashDiffers", TipKitError.invalidPredicateValueType == TipKitError.missingGroupContainerEntitlements)

// the options that bound how often a tip is shown



// the events



