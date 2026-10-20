# UTTypeIsDynamic and UTTypeIsDeclared, iOS 8.0

Rank 29 of `coordination/corpus/band-frameworks.tsv`, `LOAD-FAIL` for provenance and yattee
(`_UTTypeIsDynamic`). The armv7 cache ladder first exports both at 8.0; 6.1.3 exports
`UTTypeCopyDeclaration` and `UTTypeCreatePreferredIdentifierForTag` (both from 3.1.3).

## UTTypeIsDynamic

A dynamic identifier is a spelling. The host answers true exactly for `dyn.` in any case of the three
letters, followed by one or more components joined by single dots, each of ASCII letters, digits and
hyphens and neither starting nor ending with a hyphen; `dyn.` alone, a doubled dot, a trailing dot,
an underscore, a space or a non-ASCII letter answer false, and so does `NULL`.
`tests/backports/host/uttype` holds the port to the host over 200000 generated identifiers around the
prefix (11268 of them dynamic by the host, the control that the generator reaches the true side): 0
different.

## UTTypeIsDeclared

True when the release's type database has a declaration for the identifier, which is what
`UTTypeCopyDeclaration` answers; a dynamic identifier has none. `NULL` is false. On the host the two
agree for declared, undeclared, empty and dynamic identifiers.

## On the device

A daemon on an iPad 2 running 6.1.3 with the port compiled in, 15 checks, 0 failures (`tests/backports/device/uttypedynamic8.m`): `public.jpeg` (and `public.JPEG`), `public.png`, `public.data`, `public.item`,
`com.apple.quicktime-movie`, `public.mpeg-4` and `com.adobe.pdf` are declared and not dynamic; an
undeclared name, the empty string and a `dyn.` identifier are not declared; the release's own
identifier for the unknown extension `zzqq` is `dyn.age81y8xvse` (the host makes the same), dynamic and
not declared; its identifier for `jpg` is declared.

## UTType

`UIKit/UTType.m`'s `isDynamic` and `isDeclared` call these through a weak reference. On 6.1.3 that
reference used to be `NULL`, and the class answered `NO` and `YES` for every identifier, wrong for a
dynamic one; built into the same library, the functions now answer for it.
