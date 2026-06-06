# 2. Terminal layer

The terminal layer covers everything needed to drive a terminal reliably across platforms. It sits on top of [LuaSystem](https://github.com/lunarmodules/luasystem) and provides initialization, ANSI sequence helpers, state management via stacks, non-blocking input, and terminal querying.

## Initialization & shutdown

Before use the terminal must be initialized with `terminal.initialize`, and cleaned up afterwards with `terminal.shutdown`. The most convenient way to do both is `terminal.initwrap`, which wraps a function call and handles setup and teardown automatically.

Platform differences between Windows and *nixes are handled here.

## Functions vs strings

Every low-level function that controls the terminal also has a `_seq` counterpart that returns the escape sequence as a string instead of writing it directly. For example:

- `terminal.clear.eol` / `terminal.clear.eol_seq`
- `terminal.cursor.shape.set` / `terminal.cursor.shape.set_seq`

These two calls are equivalent:

    local t = require "terminal"

    -- directly write
    t.cursor.shape.set("block_blink")

    -- manually write
    t.output.write(t.cursor.shape.set_seq("block_blink"))

For simple cases the direct function is fine. When drawing complex items, batching multiple sequences into a single write reduces flicker and improves performance:

    t.write(
      t.cursor.position.column_seq(1),
      "|",
      t.clear.eol_seq(),
      t.cursor.position.down_seq(),
      "|",
      t.clear.eol_seq(),
      t.cursor.position.down_seq(),
      "|",
      t.clear.eol_seq(),
      t.cursor.position.up_seq(2)
    )

Sequences can also be stored in a variable for reuse:

    local three_line_box = table.concat {
      t.cursor.position.column_seq(1),
      "|",
      t.clear.eol_seq(),
      t.cursor.position.down_seq(),
      "|",
      t.clear.eol_seq(),
      t.cursor.position.down_seq(),
      "|",
      t.clear.eol_seq(),
      t.cursor.position.up_seq(2)
    }

    t.write(three_line_box)

A more advanced version of this pattern is the `Sequence` class.

**Important**: stack-based functions are not suited for inclusion in stored strings, because they capture state at the time the string is *created*, not at the time it is *used*. The `Sequence` class supports lambda functions to handle this use case.

## Stacks

Terminal state is mostly non-queryable (cursor position is the only exception). When a piece of code changes the foreground color it cannot reliably restore the previous one without knowing what it was. Stacks solve this.

Each piece of state has its own stack with three operations:

- `push(values...)` — push new value(s) onto the stack and apply them.
- `pop(n)` — pop `n` items and re-apply the new top.
- `apply()` — re-apply the current top (undoes any intermediate changes).

Available stacks:

- **cursor shape** — shape and blink behaviour of the cursor. See stack-based functions in `terminal.cursor.shape`.
- **cursor visibility** — whether the cursor is shown. See stack-based functions in `terminal.cursor.visible`.
- **cursor position** — the only queryable state; `terminal.cursor.position.push` saves the current position and moves to the new one, `pop(n)` restores the last popped position. See stack-based functions in `terminal.cursor.position`.
- **scroll region** — the rows that scroll. See stack-based functions in `terminal.scroll`.
- **text attributes and color** — colors plus attributes like `reverse` and `blink`. See stack-based functions in `terminal.text`.

## Async / non-blocking input

The terminal library is designed for async use. Keyboard input is always non-blocking, so it works in both a blocking loop and a coroutine-based yielding loop.

Output written to the terminal is synchronous; the library assumes it will not block (or only very briefly).

The non-blocking behaviour is configured via the `sleep` and `bsleep` options passed to `terminal.initialize`.

## Querying

Querying the terminal (e.g. reading cursor position) works by writing a command code and then reading the response from stdin. The complication is that the response is appended to whatever was already in the input buffer, so any non-response bytes must be buffered on the Lua side for later consumption.

This is handled by `terminal.input`, specifically `terminal.input.preread` and `terminal.input.read_query_answer`.

**Note**: queries are slow by nature — see the performance note in the `terminal.input` module documentation for details and guidance on how to avoid accumulating query latency when redrawing a screen.
