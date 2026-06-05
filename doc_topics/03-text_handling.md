# 3. Text handling

Text handling in a terminal has several challenges. With Lua even more so, since Lua strings are byte arrays and any encoding must be handled manually. This library standardizes on UTF-8 (during terminal initialization it sets UTF-8 as the encoding on Windows to create cross-platform consistency).

Besides encoding there is also the display width of characters. Non-western languages and special characters like emojis are often displayed as 2 columns wide. For some characters there is no defined display width at all.

To handle these problems the library provides several convenience functions and classes.

**Important**: for writing to the terminal, use the `terminal.output` module — not the standard Lua `io` functions. If needed, the Lua functions can be patched with those provided in `terminal.output`.

## Character display width

Not all characters have a predefined width (east-Asian characters can have ambiguous widths). Even using LuaSystem's width functions, unknowns remain. The only reliable way to know how a character renders — single or double column — is to test it in the actual terminal.

Utility functions for this are in `terminal.text.width`.

## Displaying strings

Proper character alignment is essential for a good-looking terminal UI. The following tools help:

- `EditLine` — a cursor-based string editor that tracks position in both UTF-8 characters and display columns. See `EditLine.format` for display-oriented output.
- `terminal.utils.utf8sub` — like `string.sub` but operates on UTF-8 characters.
- `terminal.utils.utf8sub_col` — like `string.sub` but operates on display columns.
- `terminal.size` — returns the terminal dimensions (rows and columns), useful for checking whether text will fit or overflow.
