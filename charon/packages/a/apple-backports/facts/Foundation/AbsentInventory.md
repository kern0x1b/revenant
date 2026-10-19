# What Foundation still owes, counted by class, and where the family list stands

The number a slice is cut from is computed, not written down:
A registry walk by class (removed), with an optional framework, takes every row whose status is
`absent`, groups it by the class or protocol that owns it, and prints the file each group's first row
lives in. Run without an argument it counts `Foundation`.

```
# output of the removed registry walk by class, as measured:
  12  NSAttributedString                            ios15-16.json
   5  NSFileManager                                  ios11.json
   5  NSMutableURLRequest                           ios11.json
   5  NSUndoManager                                 ios11.json
   4  NSXPCInterface                                ios11.json
   4  NSURLSessionStreamDelegate                     ios11.json
   3  NSFileProviderService                          ios11.json
   3  NSURLSessionTaskDelegate                       ios11.json
   …
109 absent Foundation row(s) over 63 class group(s)
```

**The twelve the family was scoped on are two on this base.** `NSAttributedString` held twelve absent
rows when the family was cut; ten of them were answered by series that have since landed, and what is
left in the group is

```
NSAttributedStringMarkdownParsingOptions   class  introduced 15.0   absent
NSAttributedStringMarkdownSourcePosition   class  introduced 16.0   absent
```

Both are the markdown parser's options and its source-position type: the classes an application
constructs to hand a markdown string to `-[NSAttributedString initWithMarkdown:options:baseURL:]`, which
is itself one of the ten that landed. So the slice that follows the two is `NSFileManager` (5),
`NSMutableURLRequest` (5) and `NSUndoManager` (5), and the twelve-row figure is history rather than work.

How a row leaves `absent`, in this registry's words: `implemented` with the measurement it rests on in
`source`; `inert` when the port declares the name and nothing ever carries it, with that reason; and
`absent` only for what is physically absent, which is why an unmeasured row is owed a case rather than
left here. The next family commits the differential first, and a row moves only when a case reads it.
