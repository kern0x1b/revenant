// UIKit26_4.m - the 26.4 band, and the row that lands with no symbol behind it.
//
// ONE OBJECT, ONE RELEASE: 26.4, on its own.  A reader is the only thing that would notice this in
// UIKit26_0.m, because release-split reads band points only.
//
// UITextInput.unobscuredContentRect IS NOT CARRIED, AND WHY IS NOT A SHORTCUT.  The obvious objection to
// leaving a property row unimplemented is that the port could spell a CGRect accessor for it - which the
// first version of this file did, as a category on NSObject.  That put the object and the row in direct
// opposition: the row said "the accessor is not declared, so respondsToSelector: answers NO and an unchecked
// call raises" while the object declared it.  The gate reads the OBJECT, and it was right to.  The accessor
// is gone.
//
// THE REASON IS NOT THE ONE THIS FILE USED TO GIVE, and the difference matters.  The old reason was that
// the SDK 26.2 surface does not declare the name - true, and still true, because a 26.4 name cannot appear
// in a 26.2 surface by construction - which made the row's own SIGNATURE unreadable and left it owed.
// The reason it lands now is measured, and it is the same reason the twenty-nine 26.0 protocol-member rows
// land: UITextInput is a @protocol in every band end this port stages - 6.1.3, 12.0, 16.0 and 18.0, all
// four answering `protocol` and not `class` for it - so A CATEGORY CANNOT BE ON A PROTOCOL, and a protocol
// property has no accessor for a port to define under the protocol's own name.  The selector being old is
// not a reason to write it: first-rung answers 8.0 for `unobscuredContentRect`, and the owner of it in
// every release that carries it is WebKit's WAKScrollView or WKContentView, never UITextInput - which is the
// trap a selector's rung sets, that it says nothing about its own owner.
//
// So the row is `absent`: the release carries no class for this member and no release has ever had
// UITextInput carrying it.  facts/UIKit/ConverseAndWriteTools18.md has the inventories, the ladder answer and
// the controls.  What this object therefore carries is nothing, and that is the honest end rather than a
// symbol nothing exports.
