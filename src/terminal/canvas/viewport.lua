--- A viewport that maps a virtual coordinate space onto a Canvas.
--
-- This viewport is useful if a canvas is displayed in a TUI panel for example
-- and you want to draw using a fixed logical coordinate system that is independent
-- of the actual canvas pixel dimensions. The viewport applies a linear transformation
-- to map virtual coordinates to the underlying canvas pixel coordinates, optionally
-- preserving aspect ratio with letterboxing/pillarboxing.
--
-- **Responsibility:** pure coordinate transformation. This class translates
-- drawing calls expressed in a user-defined virtual pixel space into the
-- underlying Canvas's physical pixel space. It owns no scene data and records
-- no operations; the caller is responsible for re-issuing draw calls whenever
-- the canvas dimensions change (e.g. on panel resize).
--
-- **What it is NOT:**
--
-- - Not a scene graph or display list. It does not remember what was drawn.
-- - Not responsible for creating or managing the Canvas lifetime.
-- - Not responsible for rendering or writing to the terminal.
--
-- **Virtual coordinate space:**
-- Coordinates are 0-based, with origin (0, 0) at the top-left, x increasing
-- to the right and y increasing downward — matching the Canvas pixel convention.
-- The virtual space has a fixed logical size (`width` × `height`) set at
-- construction. Drawing calls use these logical coordinates regardless of the
-- physical canvas dimensions.
--
-- **Scale modes:**
-- When the virtual aspect ratio does not match the physical canvas pixel aspect
-- ratio, the viewport applies one of the following scale modes:
--
-- - `scale_modes.stretch`: x and y are scaled independently to fill the canvas exactly.
--   The image may be distorted.
-- - `scale_modes.fit`: uniform scale so the virtual space fits entirely within the canvas.
--   Unused bands (letterbox / pillarbox) are left blank. No clipping.
-- - `scale_modes.fill`: uniform scale so the virtual space fills the canvas completely.
--   Content that falls outside the canvas bounds is clipped (silently ignored,
--   matching Canvas out-of-bounds behaviour).
--
-- **Resize handling:**
-- The viewport holds a reference to a Canvas. When the panel is resized, the
-- caller should replace the canvas via `set_canvas` and then re-issue all
-- drawing calls.
--
-- Example usage:
--     local Canvas = require "terminal.canvas"
--     local CanvasViewport = require "terminal.canvas.viewport"
--
--     -- Inside a Panel content callback, called on every render (including resize):
--     local c = Canvas({ width = panel.inner_width, height = panel.inner_height })
--     local vp = CanvasViewport({
--       canvas = c, width = 300, height = 300,
--       scale_mode = CanvasViewport.scale_modes.fit,
--       anchor = CanvasViewport.anchors.center,
--     })
--     vp:line({ x1 = 0, y1 = 0, x2 = 299, y2 = 299 })  -- diagonal in virtual space
--     -- position cursor and write c:render() as usual
--
-- @classmod canvas.Viewport

local utils = require "terminal.utils"
local floor = math.floor
local min = math.min
local max = math.max

local CanvasViewport = utils.class()



--- Scale mode constants; `stretch`, `fit`, or `fill` determine how the virtual
-- coordinate space is mapped to the underlying canvas when their aspect ratios do not match.
-- @field canvas.Viewport.scale_modes table lookup table for scale mode constants.
CanvasViewport.scale_modes = utils.make_lookup("scale_mode", {
  stretch = "stretch",
  fit = "fit",
  fill = "fill",
})



--- Anchor constants; `center` or `top_left` determine the alignment of the virtual space within the
-- canvas when `scale_mode` is `fit` or `fill`. With `center` the virtual space is centered in the
-- canvas, and with `top_left` the virtual space is aligned to the top-left corner of the canvas.
-- This has no effect when `scale_mode` is `stretch` since the virtual space always fills the canvas
-- in that mode.
-- @field canvas.Viewport.anchors table lookup table for anchor constants.
CanvasViewport.anchors = utils.make_lookup("anchor", {
  center = "center",
  top_left = "top_left",
})



-- Recompute cached scale factors and offsets from the current canvas dimensions.
local function compute_scales(self)
  local ph, pw = self._canvas:get_pixels()
  local vw = self._virt_w
  local vh = self._virt_h
  local sx, sy, ox, oy

  if self._scale_mode == CanvasViewport.scale_modes.stretch then
    sx = pw / vw
    sy = ph / vh
    ox = 0
    oy = 0
  else
    local s
    if self._scale_mode == CanvasViewport.scale_modes.fit then
      s = min(pw / vw, ph / vh)
    else -- fill
      s = max(pw / vw, ph / vh)
    end
    sx = s
    sy = s
    if self._anchor == CanvasViewport.anchors.center then
      ox = floor((pw - vw * s) / 2)
      oy = floor((ph - vh * s) / 2)
    else -- top_left
      ox = 0
      oy = 0
    end
  end

  self._sx = sx
  self._sy = sy
  self._ox = ox
  self._oy = oy
end



--- Create a new CanvasViewport.
-- Do not call this method directly, call on the class instead.
-- @tparam table opts
-- @tparam Canvas opts.canvas The underlying Canvas to draw into.
-- @tparam number opts.width  Virtual space width in logical pixels.
-- @tparam number opts.height Virtual space height in logical pixels.
-- @tparam[opt=scale_modes.stretch] string opts.scale_mode One of `CanvasViewport.scale_modes`.
-- @tparam[opt=anchors.center] string opts.anchor Alignment of the virtual space within the
--   canvas when `scale_mode` is `scale_modes.fit` or `scale_modes.fill`. One of `CanvasViewport.anchors`.
-- @usage
-- local vp = CanvasViewport({
--   canvas = c,
--   width = 300,
--   height = 300,
--   scale_mode = CanvasViewport.scale_modes.fit,
--   anchor = CanvasViewport.anchors.center,
-- })
function CanvasViewport:init(opts)
  assert(opts and opts.canvas, "canvas is required")
  assert(opts.width and opts.height, "width and height are required")
  assert(opts.width > 0 and opts.height > 0, "width and height must be positive")

  self._canvas = opts.canvas
  self._virt_w = opts.width
  self._virt_h = opts.height
  self._scale_mode = CanvasViewport.scale_modes[opts.scale_mode or CanvasViewport.scale_modes.stretch]
  self._anchor = CanvasViewport.anchors[opts.anchor or CanvasViewport.anchors.center]
  compute_scales(self)
end



--- Replace the underlying canvas.
-- Call this when the panel has been resized and a new Canvas has been created
-- with updated dimensions. Scale factors are recomputed immediately.
-- @tparam Canvas canvas The new Canvas instance.
function CanvasViewport:set_canvas(canvas)
  self._canvas = canvas
  compute_scales(self)
end



--- Return the current scale factors applied to virtual coordinates.
-- Useful for callers that need to reason about resolution (e.g. to decide
-- whether to simplify a dense dataset before drawing).
-- @treturn number sx  Scale factor applied to x (physical_px / virtual_px).
-- @treturn number sy  Scale factor applied to y (physical_px / virtual_px).
function CanvasViewport:get_scale()
  return self._sx, self._sy
end



--- Set (illuminate) a pixel at a virtual coordinate.
-- Out-of-bounds virtual coordinates (after mapping) are silently ignored.
-- @tparam number x Virtual pixel column, 0-based.
-- @tparam number y Virtual pixel row, 0-based.
function CanvasViewport:set(x, y)
  self._canvas:set(floor(x * self._sx) + self._ox, floor(y * self._sy) + self._oy)
end



--- Clear (extinguish) a pixel at a virtual coordinate.
-- Out-of-bounds virtual coordinates (after mapping) are silently ignored.
-- @tparam number x Virtual pixel column, 0-based.
-- @tparam number y Virtual pixel row, 0-based.
function CanvasViewport:unset(x, y)
  self._canvas:unset(floor(x * self._sx) + self._ox, floor(y * self._sy) + self._oy)
end



--- Draw a line between two virtual-space pixels.
-- @tparam table opts
-- @tparam number opts.x1 Start virtual pixel column, 0-based.
-- @tparam number opts.y1 Start virtual pixel row, 0-based.
-- @tparam number opts.x2 End virtual pixel column, 0-based.
-- @tparam number opts.y2 End virtual pixel row, 0-based.
-- @tparam[opt=false] boolean opts.erase If truthy, unset pixels instead of setting them.
function CanvasViewport:line(opts)
  local sx, sy, ox, oy = self._sx, self._sy, self._ox, self._oy
  self._canvas:line({
    x1 = floor(opts.x1 * sx) + ox,
    y1 = floor(opts.y1 * sy) + oy,
    x2 = floor(opts.x2 * sx) + ox,
    y2 = floor(opts.y2 * sy) + oy,
    erase = opts.erase,
  })
end



--- Draw an ellipse using virtual-space coordinates.
-- The virtual radii are scaled independently per axis, so a circle in virtual
-- space becomes an ellipse on the canvas when `scale_mode` is `scale_modes.stretch`.
-- @tparam table opts
-- @tparam number opts.x Centre virtual pixel column, 0-based.
-- @tparam number opts.y Centre virtual pixel row, 0-based.
-- @tparam number opts.rx Horizontal radius in virtual pixels.
-- @tparam number opts.ry Vertical radius in virtual pixels.
-- @tparam[opt=false] boolean opts.fill If truthy, fill the interior.
-- @tparam[opt=false] boolean opts.erase If truthy, unset pixels instead of setting them.
function CanvasViewport:ellipse(opts)
  local sx, sy, ox, oy = self._sx, self._sy, self._ox, self._oy
  self._canvas:ellipse({
    x = floor(opts.x * sx) + ox,
    y = floor(opts.y * sy) + oy,
    rx = floor(opts.rx * sx),
    ry = floor(opts.ry * sy),
    fill = opts.fill,
    erase = opts.erase,
  })
end



--- Draw a circle using virtual-space coordinates.
-- Convenience wrapper around `ellipse` with equal horizontal and vertical radii.
-- With `scale_modes.fit` or `scale_modes.fill` the uniform scale preserves the circular shape.
-- With `scale_modes.stretch` the circle maps to an ellipse on the canvas.
-- @tparam table opts
-- @tparam number opts.x Centre virtual pixel column, 0-based.
-- @tparam number opts.y Centre virtual pixel row, 0-based.
-- @tparam number opts.r Radius in virtual pixels.
-- @tparam[opt=false] boolean opts.fill If truthy, fill the interior.
-- @tparam[opt=false] boolean opts.erase If truthy, unset pixels instead of setting them.
function CanvasViewport:circle(opts)
  self:ellipse({ x = opts.x, y = opts.y, rx = opts.r, ry = opts.r, fill = opts.fill, erase = opts.erase })
end



--- Draw an arc using virtual-space coordinates.
-- Scales the centre and radii into physical canvas pixels, then delegates to `Canvas:arc`.
-- Angles are passed through unchanged; they describe the same geometric direction
-- regardless of scale.
--
-- Note: angles are drawn clockwise, see `Canvas:arc` for details.
-- @tparam table opts
-- @tparam number opts.x Centre virtual pixel column, 0-based.
-- @tparam number opts.y Centre virtual pixel row, 0-based.
-- @tparam number opts.rx Horizontal radius in virtual pixels.
-- @tparam number opts.ry Vertical radius in virtual pixels.
-- @tparam number opts.angle_start Start angle in radians.
-- @tparam number opts.angle_end End angle in radians (must be >= angle_start).
-- @tparam[opt=false] boolean opts.erase If truthy, unset pixels instead of setting them.
function CanvasViewport:arc(opts)
  local sx, sy, ox, oy = self._sx, self._sy, self._ox, self._oy
  self._canvas:arc({
    x = floor(opts.x * sx) + ox,
    y = floor(opts.y * sy) + oy,
    rx = floor(opts.rx * sx),
    ry = floor(opts.ry * sy),
    angle_start = opts.angle_start,
    angle_end = opts.angle_end,
    erase = opts.erase,
  })
end



--- Draw a polygon from an array of virtual-space `{x, y}` points.
-- 1 point draws a dot, 2 points draw a line, 3+ points draw a closed polygon by default.
-- @tparam table opts
-- @tparam table opts.points Array of `{x, y}` virtual pixel coordinate pairs, 0-based.
-- @tparam[opt=false] boolean opts.open If truthy, do not close the path back to the first point.
-- @tparam[opt=false] boolean opts.fill If truthy, fill the interior of the polygon.
-- @tparam[opt=false] boolean opts.erase If truthy, unset pixels instead of setting them.
function CanvasViewport:polygon(opts)
  local sx, sy, ox, oy = self._sx, self._sy, self._ox, self._oy
  local transformed = {}
  for i, p in ipairs(opts.points) do
    transformed[i] = { floor(p[1] * sx) + ox, floor(p[2] * sy) + oy }
  end
  self._canvas:polygon({
    points = transformed,
    open = opts.open,
    fill = opts.fill,
    erase = opts.erase,
  })
end



return CanvasViewport
