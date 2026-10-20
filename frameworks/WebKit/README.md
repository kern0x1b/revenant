# Revenant WebKit

**A current WebKit for hardware the web left for dead.**

A modern WebKit engine, built from source for **armv7**, running today's websites on an **iPhone 4S from 2011**: a
dual-core 800 MHz phone with 512 MB of RAM, on **iOS 6.1.3**. The engine is dropped underneath the phone's own **Mobile
Safari**, so the stock browser renders the modern web with none of its own UI replaced.

<p align="center">
  <img src="../../docs/reference/webkit/screenshots/browser-modern-web.png" alt="The bookmarks start page, the Speedometer benchmark and the Internet Archive rendered on an iPhone 4S" width="100%">
  <br>
  <em>The new-tab start page, WebKit's own Speedometer benchmark, and the Internet Archive, on an iPhone 4S in Mobile Safari.</em>
</p>

The engine the phone ships with is WebKit 536 from 2012. It cannot render a page written this decade, and it cannot
negotiate TLS with a current server. Each of those is fixed here, and the [features](../../docs/reference/webkit/features.md)
are listed there with the Settings pane.

## Build and deploy

The port is a member of revenant, built from the top of the checkout:

```sh
./xmakew f -P . -p iphoneos -a armv7
./xmakew -P .
./xmakew deb -P .
```

The requirements, the whole sequence and how to install the package on the phone are in
[build and test](../../docs/guides/webkit/build-and-test.md). The engine is upstream WebKit at a commit of `main` plus the
port's patch series, `third_party/webkit/patches`.

## Documentation

| Document | About |
| --- | --- |
| [Features and the Settings pane](../../docs/reference/webkit/features.md) | what works on the phone, and what the Settings pane writes |
| [Architecture](../../docs/explanation/webkit/architecture.md) | how the engine is loaded in place of the system one |
| [Network](../../docs/explanation/webkit/network.md) | HTTPS on a system whose TLS stopped working, and the HTTP cache |
| [Compatibility](../../docs/reference/webkit/compatibility.md) | what this OS does not have, probed on the device |
| [Memory and caches](../../docs/explanation/webkit/memory-and-caches.md) | what 512 MB forces |
| [WebGL](../../docs/explanation/webkit/webgl.md) | the ANGLE backend this port had to write |
| [Build and test](../../docs/guides/webkit/build-and-test.md) | the full build, deploy and verification |
| [Contributor guide](../../docs/guides/webkit/contributing.md) | the Safari substitution, the gotchas, the conventions |
| [Maintaining](../../docs/guides/webkit/maintaining.md) | how the port is carried against a moving engine |
| [Changelog](../../docs/reference/webkit/changelog.md) | every change, dated by the day it was measured on the device |
| [Third-party](../../docs/reference/webkit/third-party.md) | every dependency, its licence, and the screenshots' trademarks |

## License

MIT, see `LICENSE`, for the code in this repository. The engine is WebKit and keeps its own terms, LGPL-2.1-or-later and
BSD-2-Clause; the port's changes to it are the patches in `third_party/webkit/patches`, under those same terms. Every
library this operating system cannot supply is fetched from its own upstream by an xmake package, and
[third-party](../../docs/reference/webkit/third-party.md) lists each one.

Built with Claude (Anthropic). This project is developed with AI assistance, openly; see the commit history.
