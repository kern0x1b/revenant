# NSLocale, the components of iOS 10

Source: the host's own Foundation, asked for each property and for the key beside it, and the differential
run of `tests/backports/host/foundation2/run.sh`, which holds the backport to the same answers.

Every one of these properties is the value of a key the release already answers through
`-objectForKey:`, and the two agree on every locale tried - `en_US`, `zh-Hans_CN`,
`de_DE@collation=phonebook`, `en_US_POSIX`, `th_TH_TH` and the invented `xx_YY`:

| property | key |
|---|---|
| `languageCode` | `NSLocaleLanguageCode` |
| `countryCode` | `NSLocaleCountryCode` |
| `scriptCode` | `NSLocaleScriptCode` |
| `variantCode` | `NSLocaleVariantCode` |
| `exemplarCharacterSet` | `NSLocaleExemplarCharacterSet` |
| `collationIdentifier` | `NSLocaleCollationIdentifier` |
| `collatorIdentifier` | `NSLocaleCollatorIdentifier` |
| `usesMetricSystem` | `NSLocaleUsesMetricSystem`, as a boolean |
| `decimalSeparator`, `groupingSeparator` | `NSLocaleDecimalSeparator`, `NSLocaleGroupingSeparator` |
| `currencySymbol`, `currencyCode` | `NSLocaleCurrencySymbol`, `NSLocaleCurrencyCode` |
| the four quotation delimiters | the four `NSLocale…QuotationDelimiterKey` |

`calendarIdentifier` is the exception: `NSLocaleCalendar` answers an `NSCalendar`, and the property is that
calendar's own identifier. `localizedStringFor…` is `-displayNameForKey:value:` with the matching key.

What the answers look like, so that a wrong mapping shows at once: `en_US` gives language `en`, country `US`,
no script and no variant, collation `standard`, collator `en_US`, calendar `gregorian`, metric false,
currency `USD`, and `“` as the opening quotation mark; `de_DE@collation=phonebook` keeps the collation
`phonebook` and the collator `de_DE@collation=phonebook`, and quotes with `„`; `en_US_POSIX` and `th_TH_TH`
carry their variants `POSIX` and `TH`, and the Thai locale's calendar is `buddhist`; a locale nobody defines,
`xx_YY`, still answers its language and country and has no currency.
