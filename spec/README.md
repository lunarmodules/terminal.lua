# Test organization

Tests are numbered for deterministic ordering when running. Ordered from fundamentals to more higher level. Specific domains are organizaed in ranges.

## numbering scheme



- 00 is for the test helpers
- 01 - 19 are for generic utilities used everywhere
  - 01 is for utils
  - 02 is for `Sequence` class
  - 03 is for `EditLine` class
  - from there the ANSI sequence generating modules (color, cursor, etc)
- 20 - 49 are for the `ui` modules in `terminal.ui.*` range
  - 20 is for `Panel` base class
  - from there the derived modules
- 50 - 79 are for the `cli` modules in `terminal.cli.*` range
  - no particular order
