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

line("file.failedToLoadData.itself", AppIntents.IntentFile.IntentFileError.failedToLoadData == .failedToLoadData)
line("file.failedToLoadData.other", AppIntents.IntentFile.IntentFileError.failedToLoadData != .failedToLoadFile)
