import CoreText

// The iOS 6 reading of CTFontManagerCreateFontDescriptorsFromURL (iOS 7), implemented by CoreTextBackports as
// revenant_CTFontManagerCreateFontDescriptorsFromURL. Declared here by its own name, so the Swift importer does
// not see the SDK function with its iOS 7 availability. The result is retained, as the SDK function's is.
@_silgen_name("revenant_CTFontManagerCreateFontDescriptorsFromURL")
internal func revenantCTFontManagerCreateFontDescriptorsFromURL(_ url: CFURL) -> CFArray?
