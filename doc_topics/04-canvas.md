# 4. Canvas (braille pixel graphics)

The `terminal.canvas` module family provides a pixel-level drawing surface built on Unicode
Braille characters. Each terminal cell holds one braille character (U+2800–U+28FF), which
encodes a 2×4 dot grid — so a canvas that is **W columns × H rows** in terminal space exposes
**2W × 4H pixels**.

Three classes build on each other:

- `Canvas` — the raw pixel grid and all drawing primitives.
- `canvas.Viewport` — maps a fixed virtual coordinate space onto a canvas with scaling and alignment.
- `canvas.TimeSeriesGraph` — a ready-made scrolling data graph drawn on a canvas.

## 4.1 Canvas

A `Canvas` owns a grid of braille cells. Pixel coordinates are **0-based**, origin at the
top-left, x increasing right, y increasing down. Drawing outside the bounds is silently
ignored.

The canvas can be rendered with `render()`. Without options, cursor movement sequences are
included so the cursor returns to the top-left of the block after rendering — suitable for
use inside a TUI layout. Pass `print = true` to get plain newline-separated output instead.

See the `Canvas` class reference for all drawing primitives (`line`, `ellipse`, `circle`,
`arc`, `polygon`) and canvas management methods (`clear`, `resize`, `scroll`, `roll`).

## 4.2 canvas.Viewport

Drawing directly in physical pixels is inconvenient when the canvas size changes (e.g. on
terminal resize). `canvas.Viewport` solves this by providing a **fixed virtual coordinate
space** that it maps to the underlying canvas via a linear transform.

Three scale modes control what happens when the virtual and physical aspect ratios differ:

- `stretch` — x and y scaled independently; fills the canvas exactly, may distort.
- `fit` — uniform scale; fits inside the canvas, leaving blank letterbox/pillarbox bands.
- `fill` — uniform scale; fills the canvas, clipping content outside the bounds.

The `anchor` option (`center` or `top_left`) positions the virtual space within any blank
bands that appear in `fit` mode.

On terminal resize, call `set_canvas` with a new canvas and re-issue all drawing calls.
`canvas.Viewport` exposes the same drawing primitives as `Canvas`, using virtual coordinates.

See `examples/canvas.lua` for a working demo.

## 4.3 canvas.TimeSeriesGraph

`canvas.TimeSeriesGraph` renders a scrolling data plot. It manages a sliding sample window,
Y-axis bounds, tick marks, and labels. Push values with `push()`, then either draw onto an
existing canvas with `draw(canvas)` or let it create one internally via `render({ cols, rows })`.

When `min`/`max` are omitted, the range expands dynamically, snapping to the nearest "nice"
number (1/2/5 × 10ⁿ).

See `examples/graph.lua` for a working demo.
