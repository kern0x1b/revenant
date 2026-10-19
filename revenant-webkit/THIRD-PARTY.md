# Third-party code, and where each piece stands

This repository contains no third-party source. Every dependency below is
declared in `charon.toml`, pinned in `conan.lock`, and built by a recipe that
names the upstream git commit it fetches; nothing is vendored. The engine is a
git submodule pointing at a fork of WebKit, so its code and its licenses live in
that repository rather than this one.

The point of this file is that a reader can tell, without building anything,
exactly what this project links against and under what terms.

## The engine

| Component | Where it comes from | License |
| --- | --- | --- |
| WebKit 2.54 | `webkit-254` submodule — the `main` branch of a fork; this port's changes are commits on that branch | LGPL-2.1-or-later and BSD-2-Clause, as WebKit ships them: `Source/WebCore/LICENSE-LGPL-2.1`, `Source/WebCore/LICENSE-APPLE`, `Source/JavaScriptCore/COPYING.LIB` |
| ANGLE | inside the WebKit tree, `Source/ThirdParty/ANGLE`; the EAGL backend this port adds lives there under the same terms | BSD-3-Clause, `Source/ThirdParty/ANGLE/LICENSE` |

## Libraries this operating system cannot supply

Each is fetched by the recipe named beside it, at the version named beside it,
and built for armv7. Each package carries its upstream license file under
`licenses/`. None is redistributed here.

| Component | Version | License | Fetched by |
| --- | --- | --- | --- |
| libc++, libc++abi | 23.1.1 | Apache-2.0 with the LLVM exception | `libcxx` recipe (Charon) |
| ICU | 78.3 | Unicode license (ICU) | `recipes/icu` |
| OpenSSL | 4.0.2 | Apache-2.0 | `recipes/openssl` |
| libpsl | 0.23.3 plus 5 commits (`0.23.3+5.ga629c83`) | MIT; the Public Suffix List data it carries is MPL-2.0 | `recipes/libpsl` |
| libwebp | 1.6.0 plus 258 commits (`1.6.0+258.g6ff2f43`) | BSD-3-Clause | `recipes/libwebp` |
| libxml2 | 2.15.4 | MIT | `recipes/libxml2` |
| libxslt | 1.1.45 | MIT | `recipes/libxslt` |
| woff2 | 1.0.2 plus 13 commits (`1.0.2+13.gfb9c337`) | MIT | `recipes/woff2` |
| brotli | 1.2.0 plus 161 commits (`1.2.0+161.g85c2aaf`) | MIT | `recipes/brotli` |
| wasm3 | 0.9.1-beta.1 plus 7 commits (`0.9.1-beta.1+7.gdeeaca9`) | MIT | `recipes/wasm3` |

## Tools that build it

These run on the build machine and are linked into nothing that reaches the
phone.

| Component | Version | License | Fetched by |
| --- | --- | --- | --- |
| ld64, from cctools-port | 956.6 | Apple Public Source License 2.0, `cctools/ld64/APPLE_LICENSE` | `ld64` recipe (Charon) |
| apple-libtapi, which ld64 loads to read the SDK's `.tbd` stubs | as pinned in the recipe | Apache-2.0 with the LLVM exception (`src/LICENSE.txt`), plus the University of Illinois/NCSA licenses its tapi and LLVM parts carry | `ld64` recipe (Charon) |

The `ld64` package holds the linker, `libtapi.dylib` and those license files,
and nothing else. cctools-port builds a whole toolchain beside the linker - its
assembler among it, which is GPL-2.0 - but none of that is used here, so none of
it is packaged.

## The one third-party file that is in this repository

| File | What it is | License |
| --- | --- | --- |
| `app/cacert.pem` | the CA certificate bundle the TLS backend verifies against: the public root certificates extracted from Mozilla's `certdata.txt` by the curl project's `mk-ca-bundle.pl` | The certificates are the certificate authorities' own, published to be distributed. Mozilla's `certdata.txt`, which they are extracted from, is MPL-2.0; the extract carries no license header of its own, only its provenance, date and SHA-256 |

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

`scripts/check-cacert.py` verifies the file against the SHA-256 this project
reviewed - `f66dff1b…480bc9` - and with `--upstream` compares it against what
<https://curl.se/ca/cacert.pem> serves today, printing what to do if they differ
rather than replacing anything.

## Things this project deliberately does not carry

- **No fonts, and nothing that moves one.** A font is not a browser engine's
  business. Moving a current emoji font onto a 2013 device is a separate thing
  and lives in its own project; four checks on `tests/device/text-and-emoji.html`
  simply measure what the device can draw, and say so.
- **No test corpus of other people's pages.** `tests/device/sweep.py` ships with
  no site list: it loads only what the operator names on the command line or in
  a gitignored file of their own. Driving a browser at somebody's site from an
  automated run is a matter between that operator and that site's terms, and it
  is not something a repository should decide on their behalf. Everything the
  automated suite loads is served from `tests/device/` on the operator's own
  machine.
- **No conformance suite.** Khronos' WebGL conformance tests are cloned by the
  operator when they want to run them; `tests/device/conformance.py` says how.
  They are not vendored and not modified.
- **No device credentials.** `device.env` is gitignored; `device.env.example`
  shows its shape.

## This project's own code

MIT, `LICENSE`. That covers what is in this repository: the compatibility
library, the port's tooling, the tests, the packaging and the documentation.
