# +[UIActivity activityCategory], iOS 7

`UIActivity` is a real class of iOS 6; `activityCategory` is an override point the SDK header
of 9.3 documents as arriving in iOS 7.0, with a stated default of `UIActivityCategoryAction`.
Nothing on iOS 6 asks a `UIActivity` subclass for its category, so there is no host to differ
against: the backport gives the base class the same default the header states, and a subclass
that overrides the class method changes the answer exactly as `+[NSObject class]` overriding
lets any class method be replaced.
