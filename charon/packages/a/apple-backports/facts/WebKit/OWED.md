// OWED.md -- what the WebKit registry still owes, counted, not guessed.
//
// Written by .agent-work/owed/count-owed.py against the iPhoneOS 26.2 SDK in the shared xmake store and
// the registry at tip 1c40830aa245, which carries 161 rows. A row is OWED when the SDK header declares a public
// member and no row names it. Classes are listed biggest first, and the biggest one is where the next
// family is built.
//
// The registry spells a METHOD in brackets (+[Class sel]) and a PROPERTY in dot form (Class.name), and
// the count has to spell a member the way the registry does or every property reads as owed: the first
// run of this scan did not, and it charged WKWebExtensionContext for 28 members that 48 rows already
// cover.
//
// The scan reads the headers as text, so one limit is stated rather than hidden: it is a FLOOR for
// methods, since a declaration it misses lowers a count. It drops a property's setter once the getter
// is declared, and it reads 48 header constants of which 26 have no row; constants are counted apart
// from the classes below, because a constant belongs to no one class.
//
// Regenerate: python3 .agent-work/owed/count-owed.py <26.2 Headers dir> packages/a/apple-backports/registry/WebKit/base.json
//
// | owed | class | what it is |
// | ---: | --- | --- |
| 20 | `WKWebView` | the view itself: navigation, the UIDelegate, the URL, back/forward gestures |
| 9 | `WKWebExtensionTabConfiguration` | how one tab of the console is configured |
| 8 | `WKWindowFeatures` | the geometry and flags a new window asks for |
| 8 | `WKWebExtensionMatchPattern` | which URLs one pattern matches |
| 7 | `WKWebExtensionWindowConfiguration` | how a window the extension opens is configured |
| 6 | `WKNavigationAction` | a navigation the user or a page asked for |
| 5 | `WKWebViewConfiguration` | how a web view is set up before it loads anything |
| 5 | `WKBackForwardList` | the entries behind and ahead of the current page |
| 4 | `WKWebsiteDataStore` | the store behind a web view: cookies, caches, records |
| 4 | `WKScriptMessage` | a message a page sent into the host |
| 3 | `WKWebExtensionMessagePort` |  |
| 3 | `WKUserScript` |  |
| 3 | `WKSecurityOrigin` |  |
| 3 | `WKNavigationResponse` |  |
| 3 | `WKFindConfiguration` |  |
| 3 | `WKDownload` |  |
| 3 | `WKContentWorld` |  |
| 3 | `WKBackForwardListItem` | one entry in the back/forward list |
| 2 | `WKWebsiteDataRecord` |  |
| 2 | `WKWebExtensionAction` |  |
| 2 | `WKUserContentController` |  |
| 2 | `WKSnapshotConfiguration` |  |
| 2 | `WKPreferences` |  |
| 2 | `WKFrameInfo` |  |
| 1 | `WKWebExtensionController` |  |
| 1 | `WKPreviewElementInfo` |  |
| 1 | `WKPDFConfiguration` |  |
| 1 | `WKOpenPanelParameters` |  |
| 1 | `WKFindResult` |  |
| 1 | `WKContextMenuElementInfo` |  |
| 1 | `WKContentRuleListStore` |  |
| 1 | `WKContentRuleList` |  |

Separately, **26 header-declared constants** have no row: the error domains, notification names
and user-info keys outside the families already carried.

`WKWebExtension` is owed nothing: its twenty-two manifest members landed with the cases that hold
them, named in each row's `source`. The biggest class owing is now **`WKWebView` with 20**.
