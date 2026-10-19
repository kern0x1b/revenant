# UICommand, UICommandAlternate and the key command that is one, iOS 13

Introduced in iOS 13: a menu element that names an action by selector and sends it down the responder chain, where `UIAction` holds a
handler. `UIKeyCommand` became a `UICommand` in the same release.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), asked for every default, every equality, every exception and the
archive, and held against the backport by the `commands` group of `tests/backports/host/uikit2`; `tests/backports/device/uirest.m`
runs the same statements on a device.

## What the host answers

- `+commandWithTitle:image:action:propertyList:` and its `alternates:` form make the command. `+new` and `-init` are marked unavailable
  in the header and work: they answer a command with no title and no action.
- The property list is checked and deep copied: a value that is not a property list of the binary format - a dictionary with a number
  as a key, an `NSNull`, an `NSURL`, an array holding a plain object - raises `NSInternalInconsistencyException`, "Invalid parameter
  not satisfying: propertyListCopy". A mutable string or array that goes in is immutable when it comes out. The port checks with
  `CFPropertyListIsValid` for the binary format and copies with `CFPropertyListCreateDeepCopy`.
- Alternates are checked one by one: a modifier flags value of 0, or two alternates with the same flags, raises "Invalid parameter not
  satisfying: alternateModifierFlags != 0 && ![allAlternateModifierFlags containsIndex:alternateModifierFlags]"; something that is not
  an alternate raises the unrecognised selector `modifierFlags`. The array is copied.
- `-isEqual:` compares the action and the property list only; the title, the image, the attributes and the state do not count. `-hash` is
  the action's. `-copy` is another command, equal to the first and with the same attributes, state, discoverability title and title.
- A `UICommandAlternate` is equal to another of the same modifier flags, is its own copy, and prints as `<UICommandAlternate: 0x...>`.
- `-description` is `<UICommand: 0x...; title = T; action: foo:>`, the title left out when empty.
- The archive holds `title`, `preferredDisplayMode`, `action` (as a string), `propertyList` and `alternates` when there are any, and
  `discoverabilityTitle`, `attributes` and `states` when they are set. The system adds an internal identifier and an accessibility
  identifier that the port has no use for and does not write.
- `UICommandTagShare` is `com.apple.command-tag.share`.

## UIKeyCommand

A key command is a command with an input and modifier flags, and `-init` gives it the action `_nop`, no input and the title "". It is
equal to another of the same input and the same modifier flags and to no other - the action, the title and the property list do not
count - and its hash follows. Its description is `<UIKeyCommand: 0x...; action: foo:; input: a; modifierFlags: Cmd>`: the action left
out when there is none, `<none>` for no input, the flags left out when 0 and named `AlphaShift`, `NumPad`, `Ctrl`, `Opt`, `Shift`,
`Cmd` in that order and joined with hyphens. `+keyCommandWithInput:modifierFlags:action:discoverabilityTitle:` gives the command that
title as its title too. The key command holds no more than it did: iOS 6 sends nothing to a key command (see
`KeyboardAndAccessibility.md`); the three members iOS 15 added are held in `UIKeyCommandPriority.md`.

### The eight properties UIKeyCommand's own header declares

`UIKeyCommand.h:56-82` declares ten names of its own: `title`, `image`, `discoverabilityTitle`, `action`, `input`,
`modifierFlags`, `propertyList`, `attributes`, `state` and `alternates`. `input` and `modifierFlags` are the key command's
own since iOS 7 and the port defines both on it. The other eight it shares with `UICommand`, and it shares them the same way
here: Apple makes `UIKeyCommand` a `UICommand` in the same release (`UIKeyCommand.h:63`), so the eight are answered by
`UICommand`'s accessors over its own `_action`, `_propertyList`, `_alternates`, `_discoverabilityTitle`, `_attributes` and
`_state`, and by `UIMenuElement`'s `_title` and `_image` below that. A caller holding a `UIKeyCommand` gets UIKit's answer
either way.

Measured on the host, the port's objects and the system's in one process (the `commands` group of
`tests/backports/host/uikit2`, `commands_test.m`, the rows named):

| read | the system's own answer | the port's |
| --- | --- | --- |
| a command built by `commandWithTitle:image:action:input:modifierFlags:propertyList:`, then `setTitle:`, `setImage:`, `setDiscoverabilityTitle:`, `setAttributes:UIMenuElementAttributesDestructive`, `setState:UIMenuElementStateOn` | title `after`, discoverabilityTitle `D`, attributes `2`, state `1` | the same four |
| `-image` after that `setImage:`, against the very object passed in | the **same object**, size 1x1, scale 1 | the same |
| a command built with that image in the factory, and its `-copy` | both answer that image; and title `t`, action `foo:`, propertyList nil, alternates empty, discoverabilityTitle nil, attributes `0`, state `0` | the same |
| `setImage:nil`, then read | nil, and the title is unchanged | the same |
| all thirteen accessors, through `instancesRespondToSelector:` | YES for each | YES for each |

`setImage:` keeping the object it was handed is the one that could have gone the other way: the header says `copy`, and a copy
would have answered a different object than the one the caller passed.

The comparison responds to a wrong answer on these rows, which is what makes the table evidence rather than a green run. Two
plants in a scratch copy of the port's sources - `-setState:` that keeps nothing, and `-charon_setImage:` that drops the image
- and the run says so by name, on exactly the rows above:

    FAIL key command values:
        port   after setters ( after, D, 2, 0 )
        system after setters ( after, D, 2, 1 )
        port   image written ( NO, 0, 0, 0 )
        system image written ( YES, 1, 1, 1 )
    checks=7 failures=2

Six of the eight already carried a row - `title`, `image`, `alternates`, `attributes`, `propertyList` and `state`, all 13.0 -
and the corpus export read them `missing`, because it looks for the accessor in the owner's OWN selector list and the port
defines none of the eight on `UIKeyCommand` itself. They were answered before this was measured; `UIKeyCommand.action` (7.0)
and `UIKeyCommand.discoverabilityTitle` (9.0) had no row at all and have one now.

### `UIMenuLeaf`'s two members the 16.4 header does not carry

`UIMenuLeaf.h` of the 16.4 build SDK declares eight members; the 26.2 one declares ten.  The two it adds are
`selectedImage` (`:27`, `API_AVAILABLE(ios(17.0))`, "Image that can appear next to this action when the `state`
is `UIMenuElementStateOn`") and `repeatBehavior` (`:41`, typed `UIMenuElementRepeatBehavior`, "The leaf's
preferred repeat behavior").  This port builds against the 16.4 header, so neither name is in the protocol
declaration a caller compiles against - and a protocol cannot be given a member by a category, so what the port
can do is answer the names on the classes that conform.

Measured on Apple's own metadata, the arm64e shared cache of iOS 18.0 read with `modules/apple/objc.lua`'s
inventory, the own instance lists:

| read | result |
| --- | --- |
| `selectedImage` on `UIAction` | present, with its setter |
| `selectedImage` on `UICommand` | present, with its setter |
| `selectedImage` on `UIMenuElement` | absent - the leaf's, and both conformers carry their own |
| a method named `repeatBehavior` on `UIMenuElement`, `UIAction` or `UICommand` | **absent from all three** |

So `selectedImage` is answered on both classes Apple answers it on (`UIAction.m` and, from this band,
`UICommand+SelectedImage17.m`), and `repeatBehavior` is answered by no Apple conformer at all: it is a member
the 26.0 protocol declares and no class of the release implements, and its type `UIMenuElementRepeatBehavior`
(`UIMenuElement.h:32`) is named by no SDK this port builds against.  Its registry row is therefore `absent`
with that measurement.

The port's own `-[UIAction repeatBehavior]` and `-setRepeatBehavior:` are a different member and stay: they
answer the host's **private** pair, `UIActionRepeatBehaviorDisabled` 0 and `UIActionRepeatBehaviorEnabled` 1,
measured by that band's probe, under a type name (`UIActionRepeatBehavior`) no SDK declares.  Reading Apple's
class as having `repeatBehavior` because the port has it would be reading the port.

## In a menu

A `UICommand` is a menu element like an action. The action sheet of the context menu interaction lists it, and when it is chosen the
sheet sends its action down the responder chain with `sendAction:to:from:forEvent:` and the command as the sender, where an action runs
its handler. A command with the destructive attribute is the destructive button; a disabled or hidden one is left out.

## What differs from the host

The members of the menu leaf protocol of iOS 16 - `sender`, `presentationSourceItem`, `performWithSender:target:` - are carried
(`UIMenuLeaf.md`); the sheet now sends a chosen command through `performWithSender:target:`'s path, so `sender` is the view the
interaction belongs to while the action runs. `selectedImage` and `repeatBehavior` arrived with iOS 17 and are not in the SDK (16.4)
this port is built against; `subtitle` is `UIMenuElement`'s own (15.0), not the protocol's, and its row says why it is absent.
