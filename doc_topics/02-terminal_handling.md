# 2. Terminal handling

Terminals are hard to interact with. Sending commands is easy, but querying status
is all but impossible. This means that the state set (e.g. what is currently displayed at pos x,y, or the foreground color currently set) is
global, and non-queryable. In an async application, the global state becomes even
harder to manage.

# 2.1 Asynchroneous code

The terminal library is designed as async capable. This means that it can be used
in a coroutine based environment, in a non-blocking way.

Input can be read in a non-blocking way. Output written to the terminal is synchroneous.
The library assumes it will not block, or only very briefly.

Controlling the non-blocking input is done via the options passed to the
`terminal.initialize` function. Specifically the `sleep` and `bsleep` options.


# 2.2 Querying

Querying the terminal is done by writing a command code, and then reading the response
from the input buffer. However the data is appended to the STDIN buffer if it wasn't empty
to begin with. This means that when reading, any data that is not the response needs
to be buffered Lua side to be consumed later.

This is handled by the `terminal.input` module. Specifically the `terminal.input.preread` and
`terminal.input.read_query_answer` functions.


# 2.4 Character width

To properly control the UI in a terminal, it is important to know how text is displayed on the terminal.
The primary thing to know is the display width of characters.

The `terminal.text.width` module provides functionality to test and report the width of characters and strings, as does `terminal.preload_widths`. The `terminal.size` function can be used to find the terminal size (in rows and columns), to see if the text to display fits the screen or will roll-over/scroll.
