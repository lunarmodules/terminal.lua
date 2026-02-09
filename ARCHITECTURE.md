# Architecture

This document describes the high-level architecture of `terminal.lua`: the main concepts, module layout, and how the pieces fit together.

---

## 1. Design goals

`terminal.lua` is a cross-platform terminal library for Lua (Windows/Unix/Mac), built on top of [`luasystem`](https://github.com/lunarmodules/luasystem). Its key goals are:

- **Cross-platform terminal control** without requiring a full curses-style stack.
- **Async-friendly input**: integrate cleanly with coroutine-based event loops.
- **Reversible terminal state** via **stacks** for cursor, colors, scroll region, etc.
- **Composable output** via **functions vs `*_seq` variants** and the `Sequence` class.
- **Higher-level building blocks** for **CLI input** and **panel-based UIs**.

---

## 2. Core concepts

### 2.1 Initialization & lifecycle

The terminal must be initialized before use and restored afterwards:

- `terminal.initialize(opts)`:
  - Configures the underlying TTY / console (canonical mode, echo, non-blocking input).
  - Sets up `sys.sleep` hooks (`_sleep` / `_bsleep`) for async integration.
  - Optionally switches to an alternate screen buffer and backs up the display.
  - Handles most of the platform specifics.
- `terminal.shutdown()`:
  - Restores terminal settings and screen buffer.
  - Restores stacks (cursor position, scroll region, text attributes, etc.).

Preferred usage is via a wrapper (e.g. `initwrap`) that guarantees cleanup even on error.

### 2.2 Functions vs `*_seq` variants

Most low-level operations come in two forms:

- **Effectful function** – writes directly to the configured output stream:
  - e.g. `terminal.clear.eol()`, `terminal.cursor.shape.set("block_blink")`
- **`*_seq` function** – returns the ANSI sequence as a **string**, without writing:
  - e.g. `terminal.clear.eol_seq()`, `terminal.cursor.shape.set_seq("block_blink")`

This enables two styles:

- Simple imperative use: call the effectful functions directly.
- Composed / batched output: collect `_seq` strings, concatenate, and write once to reduce flicker and improve performance. This is powerful when used with the `Sequence` class.

### 2.3 Stacks

Terminal state (colors, cursor shape, scroll region, etc.) is **global and hard to query**. To make state reversible, the library uses stack-based APIs:

Stacks exist for:

- **Cursor shape** (`terminal.cursor.shape.stack`)
- **Cursor visibility** (`terminal.cursor.visible.stack`)
- **Cursor position** (`terminal.cursor.position.stack`) -- preferably NOT used due to slow querying.
- **Scroll region** (`terminal.scroll.stack`)
- **Text attributes and color** (`terminal.text.stack`)

Typical operations:

- `push(values...)` – pushes new state, applies it.
- `pop(n)` – pops and reapplies the previous state.
- `apply()` – reapplies the top of the stack.

> Important: stack-based functions are **not** suited to be baked into reusable strings, because their effect depends on call-time state, not creation-time state. The workaround here is to use a `Sequence` class, which supports functions/lambda's, the stack operations can be wrapped in a function.

> Important: the cursor position stack uses a query to find the current position and hence should **NOT** be used if possible. Querying is slow. If there is no risk of yielding in a coroutine implementation, then it is save to use the terminal function for backup and restore of the position which work without querying.

### 2.4 Sequence class

`terminal.sequence` provides a small **Sequence** type:

- A sequence is an array of **strings or functions**.
- Converting a sequence to a string:
  - Executes any functions and concatenates their return values.
- Sequences can be:
  - Instantiated by calling the class: `Seq("a", "b")`
  - Concatenated with `+` to form new sequences.
  - Nested inside each other.

This allows dynamic assembly of output that still works nicely with the `*_seq` pattern and stack-based functions (functions are executed at render time).

---

## 3. Module overview

The main entry point is `src/terminal/init.lua`, which exposes the `terminal` module table and wires submodules:

- `terminal.input`
- `terminal.output`
- `terminal.clear`
- `terminal.scroll`
- `terminal.cursor`
- `terminal.text`
- `terminal.draw`
- `terminal.progress`
- `terminal.sequence`
- `terminal.editline`
- `terminal.ui.panel.*`
- `terminal.cli.*`
- `terminal.utils`

### 3.1 Core modules

- **`terminal`** (`src/terminal/init.lua`)
  - Holds version metadata and high-level helpers:
    - `terminal.size()` – wrapper around `system.termsize`.
    - `terminal.bell()` / `terminal.bell_seq()` – terminal bell.
    - `terminal.preload_widths()` – preloads characters into the width cache for box drawing and progress spinners.
  - Manages initialization/shutdown and integration with `system`:
    - Console flags, non-blocking input, code page, alternate screen buffer.
    - Sleep function wiring for async usage.

- **`terminal.input`**
  - Reads keyboard input, including async / coroutine-based flows.
  - Handles query-response patterns for terminal state (e.g. cursor position) by buffering extra incoming data.
  - Uses configuration (`sleep`, `bsleep`) set during `terminal.initialize`.

- **`terminal.output`**
  - Centralizes all writes to the terminal.
  - Can patch Lua’s standard IO functions if needed (see docs).
  - All other modules write via this layer to keep behavior consistent.

- **`terminal.clear` / `terminal.scroll` / `terminal.cursor` / `terminal.text`**
  - Provide focused operations:
    - `clear`: clear screen / lines.
    - `scroll`: scroll region operations and stack.
    - `cursor`: cursor position / shape / visibility (including stacks).
    - `text`: text attributes, colors, and the text stack.
  - All follow the **functions vs `*_seq`** pattern, plus stacks where applicable.

- **`terminal.text.width`**
  - Computes display width for UTF-8 text (handles full-width / ambiguous-width characters).
  - Used by higher-level components (e.g. `EditLine`, prompts, panel titles) to keep alignment correct.

- **`terminal.utils`**
  - Shared helpers:
    - Small class system (`utils.class`).
    - UTF-8 substring helpers (`utf8sub`, `utf8sub_col`).
    - Misc utilities used across modules.

### 3.2 Higher-level building blocks

#### 3.2.1 Sequence and EditLine

- **`terminal.sequence`**:
  - The `Sequence` class (see §2.4) for constructing complex output lazily.

- **`terminal.editline`**:
  - Line-editing abstraction that:
    - Tracks cursor position both in UTF-8 characters and display columns.
    - Provides editing operations (move left/right, delete, word-wise operations).
    - Provides formatting helpers (e.g. `:format{ width = ..., wordwrap = ... }`) that are used by CLI widgets.

These are the core primitives for advanced text handling and interactive inputs.

#### 3.2.2 CLI widgets (`terminal.cli.*`)

- **`terminal.cli.prompt`** (`cli.Prompt`)
  - High-level prompt widget:
    - Renders a prompt string and an editable input value.
    - Uses `terminal.input.keymap` for key bindings.
    - Uses `EditLine`, `terminal.text.width`, `terminal.output`, and `Sequence`.
  - Contract:
    - Requires `terminal.initialize` to be called before use.
    - Provides both `Prompt{...}:run()` and callable-shortcut `Prompt{...}()` styles.
  - Handles cancellation (Esc / Ctrl-C) when configured.

- **`terminal.cli.select`**
  - Selection widget (list-style selection) built on top of the same primitives:
    - Uses `terminal.input`, `EditLine`, etc.
    - Follows the same initialization requirements as `Prompt`.

These widgets are examples of how to build higher-level interactive components on the core terminal primitives.

#### 3.2.3 Panel-based UI (`terminal.ui.panel.*`)

- **`terminal.ui.panel`** (Panel system)
  - Provides the `ui.Panel` class and related helpers:
    - Tree of panels, each either:
      - A **content panel** with a `content(self)` callback, or
      - A **divided panel** with two child panels and a split orientation.
    - Orientation constants: `Panel.orientations.horizontal` / `.vertical`.
    - Panel types: content vs split.
    - Size constraints: `min_height`, `max_height`, `min_width`, `max_width`.
    - Layout calculation: `calculate_layout(row, col, height, width)`.
    - Rendering that uses `terminal.draw`, `terminal.cursor`, `terminal.text`, etc.
  - Supports:
    - Nested layouts.
    - Borders (via `terminal.draw.box_fmt` and text attributes).
    - Named panel lookup via `panel.panels[name]`.

- **`terminal.ui.panel.screen` / `bar` / `key_bar` / `tab_strip` / `text` / `set`**
  - Additional components built on top of `ui.Panel`:
    - `Screen` – root screen abstraction for a full-terminal layout.
    - `Bar`, `KeyBar` – bar-style UI elements (status bars, key hints).
    - `TabStrip` – tab-like UI along an edge.
    - `Text` – panel for text content.
    - `Set` – collection / grouping of panels.

These modules demonstrate using the core drawing and layout primitives to construct complex UIs.

---

## 4. Async model and terminal handling

### 4.1 Async input

`terminal.lua` is designed to work in coroutine-based environments:

- Input:
  - `terminal.input.readansi` and related functions cooperate with a `sleep` function supplied via `terminal.initialize`.
  - In a coroutine-based loop, this sleep function can yield instead of blocking.
- Output:
  - Remains synchronous (writes to the terminal are assumed to be fast), but can be batched via `_seq` + `Sequence`.

The async model is largely controlled by the user-supplied `sleep` / `bsleep` functions and any event loop they integrate with.

### 4.2 Querying terminal state

For query operations (e.g. cursor position):

- A query sequence is written (e.g. via `cursor.position.get`).
- The response is read back from STDIN.
- Any unrelated data already in the input buffer must be buffered and re-used later.

This is encapsulated by **`terminal.input`** (e.g. `preread` and `read_query_answer`) so higher-level code does not have to manage raw buffers.

---

## 5. Text handling in the UI

Terminal UI must align and truncate text by **display columns**, not by bytes or UTF-8 character count. Characters can be one or two columns wide (e.g. CJK, emojis), and some have ambiguous width. This section describes how to handle width, substrings, and formatted display so text renders correctly.

### 5.1 Display width

- **`terminal.text.width`** provides the width primitives:
  - **`utf8cwidth(char)`** – width in columns of a single character (string or codepoint). Uses a cache when available; otherwise falls back to `system.utf8cwidth`.
  - **`utf8swidth(str)`** – total display width of a string in columns.
- **Width cache:** Not all characters have a fixed width (e.g. East Asian ambiguous). The library maintains a cache of **tested** widths. To populate it:
  - **`terminal.text.width.test(str)`** – writes characters invisibly, measures cursor movement, and records each character’s width. Call during startup or when you first display unknown glyphs.
  - **`terminal.preload_widths(str)`** – convenience that tests the library’s own box-drawing and progress characters plus any optional `str`. Call once after `terminal.initialize` if you use `terminal.draw` or `terminal.progress`.
- Use **`terminal.size()`** to get terminal dimensions (rows × columns) so you can fit text to the visible area.

**Rule of thumb:** For correct alignment and truncation, always reason in **columns**. Use `utf8swidth` to measure strings and `utf8cwidth` for per-character width when implementing substrings or cursors.

### 5.2 Substrings by characters vs columns

**`terminal.utils`** provides two substring functions that behave like `string.sub` but respect UTF-8 and display width:

- **`terminal.utils.utf8sub(str, i, j)`**
  - Operates on **UTF-8 character indices** (not bytes). Supports negative indices. Use when you need “first N characters” or “from character i to j” in a way that is safe across Lua 5.1 / 5.2 / LuaJIT (where `string.sub` is byte-based).
- **`terminal.utils.utf8sub_col(str, i, j, no_pad)`**
  - Operates on **display columns** `i` to `j` (1-based, non-negative). Uses `terminal.text.width.utf8cwidth` for each character. Use for:
    - Truncating a string to fit a fixed column width (e.g. a panel or status bar).
    - Extracting a slice of the display (e.g. “columns 3–10”).
  - **`no_pad`**: when the range starts or ends in the middle of a double-width character, the result can include a leading/trailing space so the returned string’s display width matches the requested column span. Set `no_pad = true` to omit that padding (result may span one column less at the edges).

**Example:** To show a string in a 20‑column slot, either truncate with `utils.utf8sub_col(s, 1, 20)` or use `EditLine` and its `format` method for multi-line or editable content.

### 5.3 EditLine: cursor, columns, and formatted display

**`terminal.editline`** (**EditLine** class) is the right tool when you need:

- Editable line(s) with a cursor.
- Positions and lengths in both **UTF-8 characters** and **display columns**.
- Word-wrapped or fixed-width formatted display (e.g. for prompts or text panels).

EditLine maintains:

- **`chars`** – array of UTF-8 characters.
- **`widths`** – per-character display width (single/double).
- **Cursor:** `pos_char()` (character index) and `pos_col()` (column index).

Key methods for display and layout:

- **`len_char()`** / **`len_col()`** – length in characters vs columns.
- **`format(opts)`** – splits the content into lines that fit a given width. Options include:
  - **`width`** – target line width in columns.
  - **`first_width`** – width of the first line (e.g. after a prompt).
  - **`wordwrap`** – wrap by words vs hard break.
  - **`pad`** / **`pad_last`** – whether to pad lines to full width.
- The **`format(opts)`** method returns a table of EditLine instances (one per line) plus the cursor’s line and column in that formatted view. Used by **`cli.Prompt`** and similar widgets to render multi-line input and place the cursor correctly.

**When to use what:**

- **Simple truncation or fixed-width slice:** use **`utils.utf8sub_col(str, 1, max_col)`** (and optionally ellipsis).
- **Editable single/multi-line text with cursor and word wrap:** use **EditLine** and **`EditLine:format(...)`**.
- **Measuring or testing width:** use **`terminal.text.width.utf8swidth`** / **`utf8cwidth`** and **`terminal.text.width.test`** / **`terminal.preload_widths`** as above.

All terminal output must go through **`terminal.output`** (e.g. `terminal.output.write`), not raw `print` or `io.write`, so that the library’s stream and any patching behave correctly.

---

## 6. How to extend

When adding new functionality:

- **New terminal capabilities** (e.g. new escape sequences):
  - Prefer adding to an existing module (`clear`, `cursor`, `text`, `scroll`, `draw`) following:
    - Function + `_seq` pattern.
    - Stack pattern when stateful and reversible.
- **New UI components**:
  - Build on `terminal.sequence`, `terminal.output`, and `terminal.text.*`.
  - For layout-heavy components, use `ui.Panel` as a basis.
- **New CLI widgets**:
  - Reuse `EditLine`, `terminal.input.keymap`, and existing patterns from `cli.Prompt` and `cli.Select`.
- **Async-aware features**:
  - Respect the `sleep` / `bsleep` hooks managed by `terminal.initialize`.
  - Avoid introducing hard-blocking operations inside tight loops.

This keeps new code aligned with the library’s core patterns and predictable for users.
