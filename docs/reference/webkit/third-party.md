# Third-party code, and where each piece stands

This repository contains no third-party source. Every dependency below is an
xmake package whose recipe names the upstream release, commit or archive checksum it
fetches; nothing is vendored. The engine is upstream WebKit at one commit, fetched by
the `webkit` package, with this port's changes as a series of patches in
`packages/w/webkit/patches`, so WebKit's code and its licenses live upstream rather than here.

The point of this file is that a reader can tell, without building anything,
exactly what this project links against and under what terms.

## The engine

| Component | Where it comes from | License |
| --- | --- | --- |
| WebKit, `main` at 2026-09-14 | `packages/w/webkit`: upstream `https://github.com/WebKit/WebKit` at the commit the recipe names; this port's changes are the patches beside it, under WebKit's terms | LGPL-2.1-or-later and BSD-2-Clause, as WebKit ships them: `Source/WebCore/LICENSE-LGPL-2.1`, `Source/WebCore/LICENSE-APPLE`, `Source/JavaScriptCore/COPYING.LIB` |
| ANGLE | inside the WebKit tree, `Source/ThirdParty/ANGLE`; the EAGL backend this port adds lives there under the same terms | BSD-3-Clause, `Source/ThirdParty/ANGLE/LICENSE` |

## Libraries this operating system cannot supply

Each is fetched by the package named beside it, at the version named beside it,
and built for armv7. Each package carries its upstream license file under
`licenses/`. None is redistributed here.

| Component | Version | License | Fetched by |
| --- | --- | --- | --- |
| libc++, libc++abi | 23.1.1 | Apache-2.0 with the LLVM exception | `libcxx` package (toolchain) |
| ICU | 78.3 | Unicode license (ICU) | `packages/i/icu` |
| OpenSSL | 4.0.2 | Apache-2.0 | `openssl` package (toolchain) |
| libpsl | 0.23.3 | MIT; the Public Suffix List data it carries is MPL-2.0 | `packages/l/libpsl` |
| libwebp | 1.6.0 | BSD-3-Clause | `packages/l/libwebp` |
| libxml2 | 2.15.4 | MIT | `packages/l/libxml2` |
| libxslt | 1.1.45 | MIT | `packages/l/libxslt` |
| woff2 | its latest commit, 2026-06-29; the last tag is 1.0.2 from 2017 | MIT | `packages/w/woff2` |
| brotli | 1.2.0 | MIT | `packages/b/brotli` |
| wasm3 | 0.9.1-beta.1 | MIT | `packages/w/wasm3` |

## Tools that build it

These run on the build machine and are linked into nothing that reaches the
phone.

| Component | Version | License | Fetched by |
| --- | --- | --- | --- |
| ld64, from cctools-port | 956.6 | Apple Public Source License 2.0, `cctools/ld64/APPLE_LICENSE` | `ld64` package (toolchain) |
| apple-libtapi, which ld64 loads to read the SDK's `.tbd` stubs | as pinned in the recipe | Apache-2.0 with the LLVM exception (`src/LICENSE.txt`), plus the University of Illinois/NCSA licenses its tapi and LLVM parts carry | `ld64` package (toolchain) |

The `ld64` package holds the linker, `libtapi.dylib` and those license files,
and nothing else. cctools-port builds a whole toolchain beside the linker - its
assembler among it, which is GPL-2.0 - but none of that is used here, so none of
it is packaged.

## The one third-party file that is in this repository

| File | What it is | License |
| --- | --- | --- |
| `examples/webview-host/cacert.pem` | the CA certificate bundle the TLS backend verifies against: the public root certificates extracted from Mozilla's `certdata.txt` by the curl project's `mk-ca-bundle.pl` | The certificates are the certificate authorities' own, published to be distributed. Mozilla's `certdata.txt`, which they are extracted from, is MPL-2.0; the extract carries no license header of its own, only its provenance, date and SHA-256 |

It is here rather than fetched, and deliberately so: a trust store is the one
dependency that must not change without somebody reading the change. It is also
the only third-party file whose absence would make the build depend on a network
for something security-relevant.

What it is for: the standalone application does HTTPS itself, through OpenSSL,
because this system's CFNetwork cannot speak modern TLS. OpenSSL verifies chains
against roots in PEM form, and the system keychain is not in a form it can read,
so the roots travel with the application. The Safari substitution does not use
this file at all - there the chain is handed back as a `SecTrustRef` and the
system evaluates it against its own store.

`tools/check-cacert.lua` verifies the file against the SHA-256 this project
reviewed - `f66dff1b…480bc9` - and with `--upstream` compares it against what
<https://curl.se/ca/cacert.pem> serves today, printing what to do if they differ
rather than replacing anything.

## Things this project deliberately does not carry

- **No fonts, and nothing that moves one.** A font is not a browser engine's
  business. Moving a current emoji font onto a 2013 device is a separate thing
  and lives in its own project; four checks on `tests/device/text-and-emoji.html`
  simply measure what the device can draw, and say so.
- **No test corpus of other people's pages.** `tests/device/sweep.lua` ships with
  no site list: it loads only what the operator names on the command line or in
  a gitignored file of their own. Driving a browser at somebody's site from an
  automated run is a matter between that operator and that site's terms, and it
  is not something a repository should decide on their behalf. Everything the
  automated suite loads is served from `tests/device/` on the operator's own
  machine.
- **No conformance suite.** Khronos' WebGL conformance tests are cloned by the
  operator when they want to run them; `tests/device/conformance.lua` says how.
  They are not vendored and not modified.
- **No device credentials.** `device.env` is gitignored; `device.env.example`
  shows its shape.

## This project's own code

MIT, `frameworks/WebKit/LICENSE`. That covers what is in this repository: the compatibility
library, the port's tooling, the tests, the packaging and the documentation.

## Trademarks and screenshots

The screenshots show third-party websites rendered by this engine, as examples of what it displays on the device. All
names, logos, page designs and content in them remain the property of their respective owners and are shown
nominatively, to demonstrate a browser engine working, under fair use. This project is not affiliated with, endorsed by,
or sponsored by any of them, and ships none of their code, assets or branding.

Nor does anything here drive a browser at somebody else's site on its own: the automated suite loads pages served from
this repository, and the one script that can load a real site takes the list from the operator.
