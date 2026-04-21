--- A viewport that maps a virtual coordinate space onto a Canvas.
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
-- The virtual space has a fixed logical size (`virt_width` × `virt_height`)
-- set at construction. Drawing calls use these logical coordinates regardless
-- of the physical canvas dimensions.
--
-- **Scale modes:**
-- When the virtual aspect ratio does not match the physical canvas pixel aspect
-- ratio, the viewport applies one of the following scale modes:
--
-- - `"stretch"`: x and y are scaled independently to fill the canvas exactly.
--   The image may be distorted.
-- - `"fit"`: uniform scale so the virtual space fits entirely within the canvas.
--   Unused bands (letterbox / pillarbox) are left blank. No clipping.
-- - `"fill"`: uniform scale so the virtual space fills the canvas completely.
--   Content that falls outside the canvas bounds is clipped (silently ignored,
--   matching Canvas out-of-bounds behaviour).
--
-- **Resize handling:**
-- The viewport holds a reference to a Canvas. When the panel is resized, the
-- caller should replace the canvas (`viewport:set_canvas(new_canvas)`) and then
-- re-issue all drawing calls. The scale factors are recomputed lazily on the
-- next draw call.
--
-- Example usage:
--     local Canvas = require "terminal.ui.canvas"
--     local CanvasViewport = require "terminal.ui.canvasviewport"
--
--     -- Inside a Panel content callback, called on every render (including resize):
--     local c = Canvas({ width = panel.inner_width, height = panel.inner_height })
--     local vp = CanvasViewport({ canvas = c, width = 300, height = 300, scale_mode = "fit" })
--     vp:line({ x1 = 0, y1 = 0, x2 = 299, y2 = 299 })  -- diagonal in virtual space
--     -- position cursor and write c:render() as usual
--
-- @classmod ui.CanvasViewport

local utils = require "terminal.utils"

local CanvasViewport = utils.class()



--- Scale mode constants.
-- @field ui.CanvasViewport.scale_modes table lookup table for scale mode constants.
CanvasViewport.scale_modes = utils.make_lookup("scale_mode", {
  stretch = "stretch",
  fit = "fit",
  fill = "fill",
})



--- Create a new CanvasViewport.
-- Do not call this method directly, call on the class instead.
-- @tparam table opts
-- @tparam Canvas opts.canvas The underlying Canvas to draw into.
-- @tparam number opts.width  Virtual space width in logical pixels.
-- @tparam number opts.height Virtual space height in logical pixels.
-- @tparam[opt="stretch"] string opts.scale_mode One of `CanvasViewport.scale_modes`.
-- @tparam[opt="center"] string opts.anchor Alignment of the virtual space within the
--   canvas when `scale_mode` is `"fit"`. One of `"center"` or `"top_left"`.
-- @usage
-- local vp = CanvasViewport({ canvas = c, width = 300, height = 300, scale_mode = "fit" })
function CanvasViewport:init(opts)
end



--- Replace the underlying canvas.
-- Call this when the panel has been resized and a new Canvas has been created
-- with updated dimensions. The next draw call will recompute scale factors.
-- @tparam Canvas canvas The new Canvas instance.
function CanvasViewport:set_canvas(canvas)
end



--- Return the current scale factors applied to virtual coordinates.
-- Useful for callers that need to reason about resolution (e.g. to decide
-- whether to simplify a dense dataset before drawing).
-- @treturn number sx  Scale factor applied to x (physical_px / virtual_px).
-- @treturn number sy  Scale factor applied to y (physical_px / virtual_px).
function CanvasViewport:get_scale()
end



--- Set (illuminate) a pixel at a virtual coordinate.
-- Out-of-bounds virtual coordinates (after mapping) are silently ignored.
-- @tparam number x Virtual pixel column, 0-based.
-- @tparam number y Virtual pixel row, 0-based.
function CanvasViewport:set(x, y)
end



--- Clear (extinguish) a pixel at a virtual coordinate.
-- Out-of-bounds virtual coordinates (after mapping) are silently ignored.
-- @tparam number x Virtual pixel column, 0-based.
-- @tparam number y Virtual pixel row, 0-based.
function CanvasViewport:unset(x, y)
end



--- Draw a line between two virtual-space pixels.
-- @tparam table opts
-- @tparam number opts.x1 Start virtual pixel column, 0-based.
-- @tparam number opts.y1 Start virtual pixel row, 0-based.
-- @tparam number opts.x2 End virtual pixel column, 0-based.
-- @tparam number opts.y2 End virtual pixel row, 0-based.
-- @tparam[opt=false] boolean opts.erase If truthy, unset pixels instead of setting them.
function CanvasViewport:line(opts)
end



--- Draw an ellipse using virtual-space coordinates.
-- The virtual radii are scaled independently per axis, so a circle in virtual
-- space becomes an ellipse on the canvas when `scale_mode` is `"stretch"`.
-- @tparam table opts
-- @tparam number opts.x Centre virtual pixel column, 0-based.
-- @tparam number opts.y Centre virtual pixel row, 0-based.
-- @tparam number opts.rx Horizontal radius in virtual pixels.
-- @tparam number opts.ry Vertical radius in virtual pixels.
-- @tparam[opt=false] boolean opts.fill If truthy, fill the interior.
-- @tparam[opt=false] boolean opts.erase If truthy, unset pixels instead of setting them.
function CanvasViewport:ellipse(opts)
end



--- Draw a circle using virtual-space coordinates.
-- Convenience wrapper around `ellipse` with equal horizontal and vertical radii.
-- With `scale_mode = "fit"` or `"fill"` the uniform scale preserves the circular shape.
-- With `scale_mode = "stretch"` the circle maps to an ellipse on the canvas.
-- @tparam table opts
-- @tparam number opts.x Centre virtual pixel column, 0-based.
-- @tparam number opts.y Centre virtual pixel row, 0-based.
-- @tparam number opts.r Radius in virtual pixels.
-- @tparam[opt=false] boolean opts.fill If truthy, fill the interior.
-- @tparam[opt=false] boolean opts.erase If truthy, unset pixels instead of setting them.
function CanvasViewport:circle(opts)
end



--- Draw a polygon from an array of virtual-space `{x, y}` points.
-- 1 point draws a dot, 2 points draw a line, 3+ points draw a closed polygon by default.
-- @tparam table opts
-- @tparam table opts.points Array of `{x, y}` virtual pixel coordinate pairs, 0-based.
-- @tparam[opt=false] boolean opts.open If truthy, do not close the path back to the first point.
-- @tparam[opt=false] boolean opts.fill If truthy, fill the interior of the polygon.
-- @tparam[opt=false] boolean opts.erase If truthy, unset pixels instead of setting them.
function CanvasViewport:polygon(opts)
end



return CanvasViewport
