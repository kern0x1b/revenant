# -[NSDateFormatter setLocalizedDateFormatFromTemplate:], iOS 8

Introduced in iOS 8.0: sets the date format of the formatter to the one its locale gives for a template of date fields (`yMMMd`, `Hm`).

Source: the host's own Foundation under Mac Catalyst (`host/tail1/run.sh`): for `en_US` the templates `yMMMd`, `yMMMMd`, `Hm`, `MMMd` and `yMd` give `MMM d, y`, `MMMM d, y`, `HH:mm`, `MMM d` and `M/d/y`; `de_DE` and `ja_JP`
give `d. MMM y` and `y年M月d日`. The device repeats them in `device/tail1.m`.

## How the port does it

`-setDateFormat:` with `+dateFormatFromTemplate:options:locale:` of the formatter's locale, which the release has had since iOS 4.
