# 3. Text handling

Text handling in a terminal has several challenges. With Lua even more since the Lua strings are essentially
byte arrays, any encoding must be manually handled. This library standardizes on UTF8 (during terminal
initialization it will set UTF8 as the encoding on Windows to create cross-platform consistency).

Besides the encoding there is also the display width of characters. Especially non-western languages and
special characters like emojis are often displayed as 2 columns wide. For some characters there isn't even a
defined display width.

To handle these problems the library has several convenience functions and classes to do the hard work for you.

**Important**: for writing to the terminal, the module `terminal.output` must be used! Not the standard Lua
functions. If needed the Lua functions can be patched with the ones provided in `terminal.output`.

# 3.1 Character display width

Some Unicode characters have an ambiguous display width (notably in
East-Asian contexts). Width calculation is delegated to the underlying
`system.utf8cwidth` and `system.utf8swidth` functions.

Ambiguous-width characters default to a width of 1 column. If required,
a different width (1 or 2) can be specified explicitly when calling
the width functions.

# 3.2 Displaying strings

In terminal displays the proper alignment of characters is a must to be able to provide a good looking UI. Hence
some utility functions/classes are provided to help with that.

- the `EditLine` class. A cursor based editor for strings. This class will also keep track of positions, both in
UTF8 characters as well as in display-columns. For display purposes check out the `EditLine.format` method.
- the `terminal.utils.utf8sub` and `terminal.utils.utf8sub_col` functions. Both behave like the standard
`string.sub` function, but the former operates on UTF8 characters (also for Lua 5.1, 5.2, and LuaJIT), and the
latter operates on display columns.
