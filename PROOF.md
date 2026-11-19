# Self-scan

<!-- budget: 0 -->

The detector run against this repository's own documentation at medium severity
or higher. Regenerate with
`npm run self-scan`; CI runs `node scripts/self-scan.js --check` and fails if
the count climbs above the budget recorded above.

Low-severity review hints are not a CI gate. Excluded by design:
`references/*/banned.md` (a list of banned words) and
`references/*/patterns.md` (each entry quotes the bad version before the good
one). Linting those would measure the wrong thing.

**0 findings across 6 files, 3394 words** — 0 high, 0 medium, 0 low.

| File | Language | Words | High | Medium | Low |
| --- | --- | --- | --- | --- | --- |
| `CONTRIBUTING.md` | en | 674 | 0 | 0 | 0 |
| `README.md` | en | 587 | 0 | 0 | 0 |
| `docs/adding-a-language.md` | en | 502 | 0 | 0 | 0 |
| `docs/architecture.md` | en | 328 | 0 | 0 | 0 |
| `docs/cloud/README.md` | ru | 585 | 0 | 0 | 0 |
| `docs/detector.md` | en | 718 | 0 | 0 | 0 |

No findings.
