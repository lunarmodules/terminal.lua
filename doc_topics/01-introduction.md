# 1. Introduction

Yet another terminal library, why? Becasue it adds a couple of things not found with other libraries:

- Also works on Windows (since it builds on top of `luasystem`)
- Works async with coroutines for keyboard input
- Has [stacks](#13-stacks) to track settings so it becomes possible to revert to previous settings, even if a piece of code has no knowledge about those settings.
- Remains Lua only, to not fall back to a full curses type implementation

## 1.1 Basic design

There are a few major concepts implemented in this library:

- [initialization & shutdown](#12-initialization--shutdown)
- [functions vs strings](#13-functions-vs-strings)
- [stacks](#14-stacks)


## 1.2 initialization & shutdown

Before use the terminal should be initialized (`terminal.initialize`) and finally it should be cleaned up (`terminal.shutdown`).

The platform specifics (Windows vs Nix'es) are handled here.

## 1.3 functions vs strings

Most functions in this library also have a string-counterpart. That would be the same function, but with an extra "_seq" appended to its name. For example;

- `terminal.clear.eol` and `terminal.clear.eol_seq`
- `terminal.cursor.shape.set` and `terminal.cursor.shape.set_seq`

The difference being that the former will write the sequence to the output stream. Where the latter returns the sequence as a string, and leaves writing to the user.

Hence these 2 examples are identical in functionality:

    local t = require "terminal"

    -- directly write
    t.cursor.shape.set("block_blink")

    -- manually write
    t.output.write(t.cursor.shape.set_seq("block_blink"))

In simple cases the regular function will do. However when drawing more complex items on a terminal screen, combining multiple write actions into a single one, can reduce flicker and improve performance.

Here's an example that draws a vertical bar (3 rows high), and clears the lines:

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

And as such it also allows for creating reusable sequences by storing it into a local variable:

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

A more advanced version of this is the `Sequence` class.

**Important**: the stack based functions are not suited for including in reusable strings, because of their dynamic nature. They would restore the state to the state from before the string was *created*, not to the state from before the stored value is actually *used*.

## 1.4 stacks

Terminal state is hard to query (the exception being the cursor position). This means that if something is changed in the state of the terminal (eg. foreground or background color) one cannot easily revert it to the previous state. This is what the stacks attempt to resolve.

For each piece of state there is a separate stack to control it. Leading to the following stacks:

- **cursor shape**: controls the shape of the cursor and whether it blinks or not.
- **cursor visibility**: controls the visibility of the cursor, which has a separate state in the terminal, and hence has its own stack.
- **cursor position**: controls the position of the cursor. This one is slightly different from the other ones, since this is the only queryable state in the terminal.
- **scroll region**: controls the rows for the scrollable region.
- **text attributes and color**: this controls colors and attributes like `reverse`, `blink`, etc.

Each stack has the following operations:

- **push(values...)**: takes value(s) for the specific stack, pushes it onto the stack, and applies it.
- **pop(n)**: pops `n` items of the stack, and applies the top of the stack again.
- **apply()**: applies the item at the top of the stack (eg. undoes any intermediate changes).

The cursor position stack operates as follows:

- **push(new_row, new_col)**: pushes the current cursor position onto the stack, and moves the cursor to the new position.
- **pop(n)**: pops `n` items of the stack, and applies the last item popped.
