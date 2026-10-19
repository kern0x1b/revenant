# Whether an XML parser resolves an external entity, and which URLs it may, iOS 8.0

Source: the SDK 26.2 headers, which say the policy defaults to
`NSXMLParserResolveExternalEntitiesNever` and that these two properties are the modern spelling of
`-setShouldResolveExternalEntities:`.

The policy is kept and **mapped onto the release's own knob**, so the port follows the release's
parser to the end: a parser told to resolve entities does resolve them, through the release's own
libxml2, and one told not to does not. That is why the value is not merely stored -- a stored policy
nothing reads would be an inert answer, and the release's `-shouldResolveExternalEntities` is exactly
the switch this property is.

The allowed set is kept and is the list the parser may resolve from: a parser given a set resolves an
entity whose URL is in it. 6.1.3's own libxml2 does the resolving; the port does not fetch anything
itself, so an entity outside the set is the parser's to refuse.
