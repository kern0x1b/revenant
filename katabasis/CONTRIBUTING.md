# Contributing

Katabasis is a research prototype. Contributions and discussion are welcome via
issues and pull requests.

- Keep changes to the translator **universal**: fixes should work for any input binary,
  not be special-cased to one app.
- Missing target-OS APIs are reported, not stubbed — they belong to a separate backports
  effort, not to the translator.
- Run the corpus (`corpus/`) and, where possible, the perf harness (`perf/`) before and
  after a change.
- Match the surrounding code style.
