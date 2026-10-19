# The user notification settings, actions and categories, iOS 8

Source: the host's own UIKit, under Mac Catalyst, held against the backport by
`tests/backports/host/uikit2/notifications_test.m` (the system's classes and the backport's, built the same way and
compared, descriptions and archives included); and iOS 6.0 and 6.1.3 on the emulator, an iPhone 4S and an iPad 2,
through `tests/backports/device/uikit2.m`. What the application does with them is in
`UIApplicationNotificationRegistration.md`.

## An action

`UIUserNotificationAction` is a value: an identifier, a title, an activation mode, whether authentication is required
and whether it is destructive. A new mutable action has no identifier and no title, activates in the foreground
(mode 0, background is 1) and is neither authenticated nor destructive. The class adopts `NSCopying`,
`NSMutableCopying` and `NSSecureCoding`: `-copy` answers an immutable `UIUserNotificationAction`, a different object,
that does not equal the original; `-mutableCopy` answers a `UIMutableUserNotificationAction`; changing a mutable copy leaves the
action it was made from as it was. Nil is accepted for the identifier and the title.

From iOS 9 an action also has a behaviour (`UIUserNotificationActionBehavior`, default 0, text input 1) and parameters (a dictionary, nil by
default). A mutable action sets both; the parameters are copied on set, as the header says, and nil is accepted. Both are carried by the copies
and by the archive, which keeps them under keys of the port's own; the release's key names for them are not compared, and the
description, which does not show them in the port, is not compared with the host's for these two.

## A category

`UIUserNotificationCategory` is an identifier and, for each of two contexts, the list of actions to offer: default is 0
and minimal is 1. A new one has no identifier and no actions - nil, not an empty array - in either context. The mutable one
takes `-setActions:forContext:` and keeps exactly the actions it is given, the objects themselves, in order, with no
limit on their number in either context (five are kept in both); nil takes the list away again.

`-copy` answers an immutable `UIUserNotificationCategory` equal to the original. A category is equal to another only
when the identifier and the actions of both contexts agree: a category with the same identifier and no actions is not equal to one
with actions, and two new empty categories are not equal to each other. The class adopts `NSSecureCoding`, and
an archive of a category holds the keys of the newest release's, less the two it adds for behaviour and parameters, which
belong to actions and not to categories; the category decoded from it has the same identifier and the same number of actions.

## Settings

`+settingsForTypes:categories:` keeps the types exactly as given - a value with every bit set is answered with every bit
set - and keeps the categories as a set of immutable copies: a mutable category given comes back as a
`UIUserNotificationCategory`. Nil categories are an empty set, and settings with nil categories equal settings with an empty set
for the same types; settings are equal when the types and the categories are equal, and differ for different types. A
new settings object has types 0 and no categories. The bits are alert 4, badge 1 and sound 2. Settings adopt
`NSSecureCoding`.

## What the description says

The classes describe themselves as the newest release does, in the form
`<UIUserNotificationSettings: address; types: (UIUserNotificationTypeAlert ...);categories: {(...)};>`, with an action
described by its identifier, title, activation mode, authentication and destructive flags; the two fields for
behaviour and parameters that the newest release adds are not part of it, since iOS 8 had neither.

## What iOS 6 does with them

Nothing is shown: iOS 6 has no notification actions, so a category is data the application keeps and the port never
offers, and the settings an application registers reach the release only as the types of its remote notifications.
