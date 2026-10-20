# The four default-version values, measured rather than chosen

`sec_protocol_options_get_default_{min,max}_{tls,dtls}_protocol_version` answer what the release's own
SSL stack negotiates by default. These numbers were **measured**, on 6.1.3 and on 6.0, and the two runs
agree on every measurement row.

## The probe, and its evidence

A program that creates an `SSLContext` and reads `SSLGetProtocolVersionMin` and `SSLGetProtocolVersionMax`
from it, for **both** a stream context and a datagram context — a stream context answers about TLS only,
so asking it about DTLS would have measured nothing. It also asks the release the 1.3 question directly,
by calling `SSLSetProtocolVersionMax(kTLSProtocol13)` and printing both the status and what the maximum
then reads.

| run | log, under the probe worktree's `.agent-work/` | sha256 |
| --- | --- | --- |
| 6.1.3 | `ssl-defaults/runs/defaults-6.1.3-20260929-152459/run.log` | `03d047d62f6de5a52ce158c91936fc402b61043c1526b39bf684122fc6e03081` |
| 6.0 | `ssl-defaults/runs/defaults-6.0-20260929-152939/run.log` | `e3f14403219210e57db131ec83cc85ab5e11654d0f4e03cd258c4793a2993eb0` |

**These are the logs that carry the rows below, and the first version of this table named two that do
not.** The `runs/p613/run.log` and `runs/p60/run.log` pair holds only `min 2`, `max 8`,
`max-after-set-13 8` and `max-after-set-13-is-13 0` - `grep -c 'dgram\|set-max-13'` returns **0** for
both - so the datagram and 1.3 rows quoted here were not in the evidence the table cited, and the
`055fc9f3...` digest under the name `probe2` is a third file's. For the record, all four:

| log | sha256 | carries the rows below? |
| --- | --- | --- |
| `ssl-defaults/runs/defaults-6.1.3-20260929-152459/run.log` | `03d047d62f6de5a52ce158c91936fc402b61043c1526b39bf684122fc6e03081` | yes |
| `ssl-defaults/runs/defaults-6.0-20260929-152939/run.log` | `e3f14403219210e57db131ec83cc85ab5e11654d0f4e03cd258c4793a2993eb0` | yes |
| `runs/p613/run.log` | `055fc9f3a914c2065fe9cb9ad850d329f6fed47ab5d22e299b866ca28f90a00a` | no |
| `runs/probe2/run.log` | `cc08039de523b2a2153fa8a5e0625f4b1459fb929fc016b1ed2b567f338c73d6` | no |

Each log names the release it ran on - `pass on iPhone2,1 6.1.3 (10B329)` and
`pass on iPhone2,1 6.0 (10A403)` - so which is which does not rest on the directory name. The two that
carry the rows **agree on every measurement line**: diffed on the rows, they are identical. They differ
in one host-side line, the emulator's "waiting for the machine to quiet down", which is about the Mac and
not about the release.

## What it found

```
ssl-defaults-probe	start      context	ok
min	2                          max	8
datagram-context	ok          dgram-min	9        dgram-max	9
set-max-13	-9830           set-max-13-illegal-param	1
max-after-set-13	8         max-after-set-13-is-13	0
ssl-defaults-probe	done
```

| row | measured | the value the port returns |
| --- | --- | --- |
| min TLS | `2` — `kSSLProtocol3`, **SSL 3.0** | `TLSv10` = `0x0301` |
| max TLS | `8` — `kTLSProtocol12` | `TLSv12` = `0x0303` |
| min DTLS | `9` — `kDTLSProtocol1` | `DTLSv10` = `0xfeff` |
| max DTLS | `9` — `kDTLSProtocol1` | `DTLSv10` = `0xfeff` |

## Two findings that changed what the rows say

**The min is not expressible.** The release's default floor is **SSL 3.0**, and
`tls_protocol_version_t` has **no SSLv3 member** — its lowest is `TLSv10` = `0x0301`. So the row returns
the enum's lowest member and the difference is recorded as a crutch rather than papered over. The earlier
value for this row was a decision, and the measurement **contradicted** it: SSL 3.0 is a worse floor than
TLS 1.0, so the decision was wrong in the direction that matters.

**TLS 1.3 is refused by the release, and that is now a measurement.** `SSLSetProtocolVersionMax
(kTLSProtocol13)` returns `-9830` = `errSSLIllegalParam`, and the maximum then reads back as 8. The row
is therefore not declining to mention 1.3 — the release declines it, on both releases tested.
