// The comparison operators a query runs, and the errors a shortcut carries: what two values of the
// same type answer, which is the question the always-true equality answered wrongly.
import Foundation
#if PORT
import AppIntents
#else
import AppIntents
#endif

func line(_ name: String, _ value: Any) { print("\(name)\t\(value)") }

line("equal.equalTo.equalTo", AppIntents.EquatableComparisonOperator.equalTo == .equalTo)
line("equal.equalTo.notEqualTo", AppIntents.EquatableComparisonOperator.equalTo == .notEqualTo)
line("string.hasPrefix.hasSuffix", AppIntents.StringComparisonOperator.hasPrefix == .hasSuffix)
line("string.hasPrefix.hasPrefix", AppIntents.StringComparisonOperator.hasPrefix == .hasPrefix)
line("comparable.lessThan.greaterThan", AppIntents.ComparableComparisonOperator.lessThan == .greaterThan)
line("hasValue.hasAnyValue.hasNoValue", AppIntents.HasValueComparisonOperator.hasAnyValue == .hasNoValue)
line("mode.and.or", AppIntents.EntityQueryComparatorMode.and == .or)
line("tile.red.red", AppIntents.ShortcutTileColor.red == .red)
line("tile.red.blue", AppIntents.ShortcutTileColor.red == .blue)
line("token.appName.appName", AppIntents.AppShortcutPhraseToken.applicationName == .applicationName)
line("focus.notFound.notFound", AppIntents.SetFocusFilterIntentError.notFound == .notFound)
line("focus.notFound.notNotFound", AppIntents.SetFocusFilterIntentError.notFound != .notFound)

// the payload types: the enum cases that carry no payload, and the resolvers, whose equality comes
// from `Resolver: Hashable` and is the answer the synthesised conformance gives.
line("file.failedToLoadData.itself", AppIntents.IntentFile.IntentFileError.failedToLoadData == .failedToLoadData)
line("file.failedToLoadData.other", AppIntents.IntentFile.IntentFileError.failedToLoadData != .failedToLoadFile)
// The resolvers have no accessible initialiser on either side -- Apple's own declaration carries only
// `resolve` and `==` (arm64e-apple-macos.swiftinterface:6172-6174) -- so there is no value of one to
// ask the question with, and the facts say so rather than the probe inventing a way to make one.
