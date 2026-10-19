# Fitting a view with priorities, iOS 8

Introduced in iOS 8.0: `-[UIView systemLayoutSizeFittingSize:withHorizontalFittingPriority:verticalFittingPriority:]`, the size
Auto Layout gives a view when the target size is a wish of a priority for each direction.

Source: the host's own UIKit under Mac Catalyst (`host/fitting/run.sh`): a view whose label wraps, asked for widths 320, 200 and 150
at the required priority for the width and the lowest for the height, for the compressed and the expanded size, for a required
height, for both required, for high and for low priorities. `device/fitting.m` holds iOS 6 to the recorded sizes.

The release has `-systemLayoutSizeFittingSize:` only, which takes the target as a wish of the lowest priority. The port puts the
target on the view for a direction whose priority is above `UILayoutPriorityDefaultLow` (at that priority and below the content's own hugging wins, as the release's answer shows for a low wish) - a width or a height constraint of
that priority - asks for the size with the target as the wish of the lowest priority for the other direction, and takes the
constraints away, so the view keeps the constraints it had.
