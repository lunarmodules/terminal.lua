local helpers = require "spec.helpers"
local lines = require("pl.stringx").splitlines

-- Mirror of canvas's internal braille() encoder, for computing expected cell values.
local function braille(i)
  return string.char(226, 160 + math.floor(i / 64), 128 + (i % 64))
end

local BLANK = braille(0)



describe("terminal.ui.canvasviewport", function()

  local Canvas, CanvasViewport

  setup(function()
    helpers.load()
    Canvas         = require "terminal.ui.canvas"
    CanvasViewport = require "terminal.ui.canvasviewport"
  end)


  teardown(function()
    helpers.unload()
  end)



  describe("init()", function()

    it("creates a viewport with valid options", function()
      local c = Canvas({ width = 5, height = 5 })
      local vp = CanvasViewport({ canvas = c, width = 100, height = 100 })
      assert.is_not_nil(vp)
    end)


    it("errors when canvas is missing", function()
      assert.has_error(function()
        CanvasViewport({ width = 100, height = 100 })
      end)
    end)


    it("errors when width or height is missing", function()
      local c = Canvas({ width = 5, height = 5 })
      assert.has_error(function() CanvasViewport({ canvas = c, height = 100 }) end)
      assert.has_error(function() CanvasViewport({ canvas = c, width  = 100 }) end)
    end)


    it("errors when width or height is not positive", function()
      local c = Canvas({ width = 5, height = 5 })
      assert.has_error(function() CanvasViewport({ canvas = c, width =  0, height = 100 }) end)
      assert.has_error(function() CanvasViewport({ canvas = c, width = -1, height = 100 }) end)
      assert.has_error(function() CanvasViewport({ canvas = c, width = 100, height =  0 }) end)
      assert.has_error(function() CanvasViewport({ canvas = c, width = 100, height = -1 }) end)
    end)


    it("errors on invalid scale_mode", function()
      local c = Canvas({ width = 5, height = 5 })
      assert.has_error(function() CanvasViewport({ canvas = c, width = 100, height = 100, scale_mode = "bad" }) end)
    end)


    it("errors on invalid anchor", function()
      local c = Canvas({ width = 5, height = 5 })
      assert.has_error(function() CanvasViewport({ canvas = c, width = 100, height = 100, anchor = "bad" }) end)
    end)


    it("defaults to stretch scale_mode", function()
      -- canvas 10x8 pixels, virtual 20x20: sx=10/20=0.5, sy=8/20=0.4 (not equal → stretch)
      local c = Canvas({ width = 5, height = 2 })  -- px: 10x8
      local vp = CanvasViewport({ canvas = c, width = 20, height = 20 })
      local sx, sy = vp:get_scale()
      assert.are.equal(10 / 20, sx)
      assert.are.equal(8  / 20, sy)
    end)

  end)



  describe("get_scale()", function()

    -- canvas 2 cols x 2 rows = 4px wide x 8px tall
    -- virtual 4x4
    -- stretch: sx=4/4=1, sy=8/4=2

    it("stretch: scales x and y independently", function()
      local c = Canvas({ width = 2, height = 2 })  -- px: 4x8
      local vp = CanvasViewport({ canvas = c, width = 4, height = 4, scale_mode = "stretch" })
      local sx, sy = vp:get_scale()
      assert.are.equal(4 / 4, sx)  -- 1.0
      assert.are.equal(8 / 4, sy)  -- 2.0
    end)


    it("fit: uses the smaller uniform scale (no overflow)", function()
      -- canvas px: 4x8, virtual 4x4 → scales: 4/4=1.0, 8/4=2.0 → fit picks min=1.0
      local c = Canvas({ width = 2, height = 2 })  -- px: 4x8
      local vp = CanvasViewport({ canvas = c, width = 4, height = 4, scale_mode = "fit" })
      local sx, sy = vp:get_scale()
      assert.are.equal(1.0, sx)
      assert.are.equal(1.0, sy)
    end)


    it("fill: uses the larger uniform scale (fills canvas, may clip)", function()
      -- canvas px: 4x8, virtual 4x4 → scales: 4/4=1.0, 8/4=2.0 → fill picks max=2.0
      local c = Canvas({ width = 2, height = 2 })  -- px: 4x8
      local vp = CanvasViewport({ canvas = c, width = 4, height = 4, scale_mode = "fill" })
      local sx, sy = vp:get_scale()
      assert.are.equal(2.0, sx)
      assert.are.equal(2.0, sy)
    end)


    it("is recomputed after set_canvas", function()
      local c1 = Canvas({ width = 2, height = 2 })  -- px: 4x8
      local vp = CanvasViewport({ canvas = c1, width = 4, height = 4, scale_mode = "stretch" })
      local sx1, sy1 = vp:get_scale()
      assert.are.equal(1.0, sx1)
      assert.are.equal(2.0, sy1)

      local c2 = Canvas({ width = 4, height = 4 })  -- px: 8x16
      vp:set_canvas(c2)
      local sx2, sy2 = vp:get_scale()
      assert.are.equal(8  / 4, sx2)
      assert.are.equal(16 / 4, sy2)
    end)

  end)



  describe("set() and unset()", function()

    -- Canvas: 2 cols x 1 row = 4px wide x 4px tall
    -- Virtual: 4x4, stretch → sx=1, sy=1 (1:1 mapping)

    it("set maps a virtual pixel to the correct canvas pixel", function()
      local c = Canvas({ width = 2, height = 1 })  -- px: 4x4
      local vp = CanvasViewport({ canvas = c, width = 4, height = 4, scale_mode = "stretch" })
      -- virtual (2, 1): physical (2, 1) → cell_col=floor(2/2)+1=2, cell_row=1
      --   dot col=2%2=0, row=1%4=1 → bit=2 → braille(2)
      vp:set(2, 1)
      assert.are.equal(BLANK,     c.cells[1][1])
      assert.are.equal(braille(2), c.cells[1][2])
    end)


    it("unset removes a previously set virtual pixel", function()
      local c = Canvas({ width = 2, height = 1 })  -- px: 4x4
      local vp = CanvasViewport({ canvas = c, width = 4, height = 4, scale_mode = "stretch" })
      vp:set(2, 1)
      assert.are_not.equal(BLANK, c.cells[1][2])
      vp:unset(2, 1)
      assert.are.equal(BLANK, c.cells[1][2])
    end)


    it("set applies scale factor correctly", function()
      -- Canvas 2x1 = 4px x 4px, virtual 8x8, stretch → sx=0.5, sy=0.5
      -- virtual (4, 0) → physical (floor(4*0.5), floor(0*0.5)) = (2, 0)
      -- cell_col=floor(2/2)+1=2, cell_row=1; dot col=0, row=0 → bit=1 → braille(1)
      local c = Canvas({ width = 2, height = 1 })  -- px: 4x4
      local vp = CanvasViewport({ canvas = c, width = 8, height = 8, scale_mode = "stretch" })
      vp:set(4, 0)
      assert.are.equal(BLANK,     c.cells[1][1])
      assert.are.equal(braille(1), c.cells[1][2])
    end)


    it("fit mode applies centering offset for the non-limiting axis", function()
      -- Canvas 2x1 = 4px wide x 4px tall, virtual 4x2
      -- fit: x_scale=4/4=1.0, y_scale=4/2=2.0 → s=min=1.0
      -- center: ox=floor((4-4*1)/2)=0, oy=floor((4-2*1)/2)=1
      -- virtual (0, 0) → physical (floor(0*1)+0, floor(0*1)+1) = (0, 1)
      -- cell_col=1, cell_row=1; dot col=0, row=1%4=1 → bit=2 → braille(2)
      local c = Canvas({ width = 2, height = 1 })  -- px: 4x4
      local vp = CanvasViewport({ canvas = c, width = 4, height = 2, scale_mode = "fit", anchor = "center" })
      vp:set(0, 0)
      assert.are.equal(braille(2), c.cells[1][1])
    end)


    it("out-of-bounds virtual coords are silently ignored", function()
      local c = Canvas({ width = 1, height = 1 })
      local vp = CanvasViewport({ canvas = c, width = 4, height = 4, scale_mode = "stretch" })
      assert.has_no_error(function() vp:set(-1,  0) end)
      assert.has_no_error(function() vp:set( 0, -1) end)
      assert.has_no_error(function() vp:set(99,  0) end)
      assert.has_no_error(function() vp:set( 0, 99) end)
      assert.are.equal(BLANK, c.cells[1][1])
    end)

  end)



  describe("line()", function()

    it("draws a horizontal line in virtual space", function()
      -- Canvas 2x1 = 4x4px, virtual 4x4, stretch 1:1
      -- line (0,0)→(3,0): same as canvas:line({x1=0,y1=0,x2=3,y2=0})
      -- each cell gets col=0,row=0,bit=1 and col=1,row=0,bit=8 → braille(9)
      local c = Canvas({ width = 2, height = 1 })
      local vp = CanvasViewport({ canvas = c, width = 4, height = 4, scale_mode = "stretch" })
      vp:line({ x1 = 0, y1 = 0, x2 = 3, y2 = 0 })
      assert.are.equal(braille(9), c.cells[1][1])
      assert.are.equal(braille(9), c.cells[1][2])
    end)


    it("applies scale to endpoints", function()
      -- Canvas 2x1 = 4x4px, virtual 8x8, stretch → sx=sy=0.5
      -- line (0,0)→(6,0): physical (0,0)→(3,0), same as 1:1 test above
      local c = Canvas({ width = 2, height = 1 })
      local vp = CanvasViewport({ canvas = c, width = 8, height = 8, scale_mode = "stretch" })
      vp:line({ x1 = 0, y1 = 0, x2 = 6, y2 = 0 })
      assert.are.equal(braille(9), c.cells[1][1])
      assert.are.equal(braille(9), c.cells[1][2])
    end)


    it("erase flag is forwarded to canvas", function()
      local c = Canvas({ width = 2, height = 1 })
      local vp = CanvasViewport({ canvas = c, width = 4, height = 4, scale_mode = "stretch" })
      vp:line({ x1 = 0, y1 = 0, x2 = 3, y2 = 0 })
      vp:line({ x1 = 0, y1 = 0, x2 = 3, y2 = 0, erase = true })
      assert.are.equal(BLANK, c.cells[1][1])
      assert.are.equal(BLANK, c.cells[1][2])
    end)

  end)



  describe("ellipse()", function()

    it("transforms centre and radii", function()
      -- Canvas 2x1 = 4x4px, virtual 8x8, stretch → sx=sy=0.5
      -- ellipse centre (4,4), rx=2, ry=2 → physical centre (2,2), rx=1, ry=1
      -- same as canvas:ellipse({x=2,y=2,rx=1,ry=1}) = canvas:circle({x=2,y=2,r=1})
      local ref = Canvas({ width = 2, height = 1 })
      ref:circle({ x = 2, y = 2, r = 1 })

      local c = Canvas({ width = 2, height = 1 })
      local vp = CanvasViewport({ canvas = c, width = 8, height = 8, scale_mode = "stretch" })
      vp:ellipse({ x = 4, y = 4, rx = 2, ry = 2 })

      for r = 1, ref.rows do
        for col = 1, ref.cols do
          assert.are.equal(ref.cells[r][col], c.cells[r][col])
        end
      end
    end)


    it("stretch mode scales rx and ry independently", function()
      -- Canvas 4x2 = 8px x 8px, virtual 4x8, stretch → sx=8/4=2, sy=8/8=1
      -- ellipse centre (2,4), rx=1, ry=1 → physical centre(4,4), rx=2, ry=1 (becomes ellipse)
      local ref = Canvas({ width = 4, height = 2 })
      ref:ellipse({ x = 4, y = 4, rx = 2, ry = 1 })

      local c = Canvas({ width = 4, height = 2 })
      local vp = CanvasViewport({ canvas = c, width = 4, height = 8, scale_mode = "stretch" })
      vp:ellipse({ x = 2, y = 4, rx = 1, ry = 1 })

      for r = 1, ref.rows do
        for col = 1, ref.cols do
          assert.are.equal(ref.cells[r][col], c.cells[r][col])
        end
      end
    end)


    it("erase flag is forwarded to canvas", function()
      local c = Canvas({ width = 2, height = 1 })
      local vp = CanvasViewport({ canvas = c, width = 4, height = 4, scale_mode = "stretch" })
      vp:ellipse({ x = 2, y = 2, rx = 1, ry = 1 })
      local had_pixels = false
      for _, row in ipairs(c.cells) do
        for _, cell in ipairs(row) do
          if cell ~= BLANK then had_pixels = true end
        end
      end
      assert.is_true(had_pixels)
      vp:ellipse({ x = 2, y = 2, rx = 1, ry = 1, erase = true })
      for r = 1, c.rows do
        for col = 1, c.cols do
          assert.are.equal(BLANK, c.cells[r][col])
        end
      end
    end)

  end)



  describe("circle()", function()

    it("delegates to ellipse with equal radii", function()
      -- circle with r=2 should produce the same result as ellipse with rx=ry=2
      local c1 = Canvas({ width = 3, height = 2 })
      local vp1 = CanvasViewport({ canvas = c1, width = 12, height = 8, scale_mode = "stretch" })
      vp1:circle({ x = 6, y = 4, r = 4 })

      local c2 = Canvas({ width = 3, height = 2 })
      local vp2 = CanvasViewport({ canvas = c2, width = 12, height = 8, scale_mode = "stretch" })
      vp2:ellipse({ x = 6, y = 4, rx = 4, ry = 4 })

      for r = 1, c1.rows do
        for col = 1, c1.cols do
          assert.are.equal(c1.cells[r][col], c2.cells[r][col])
        end
      end
    end)

  end)



  describe("polygon()", function()

    it("transforms all points before drawing", function()
      -- Canvas 2x1 = 4x4px, virtual 8x8, stretch → sx=sy=0.5
      -- polygon points (0,0),(6,0),(0,6) → physical (0,0),(3,0),(0,3)
      -- same as canvas:polygon({points={{0,0},{3,0},{0,3}}})
      local ref = Canvas({ width = 2, height = 1 })
      ref:polygon({ points = {{ 0, 0 }, { 3, 0 }, { 0, 3 }} })

      local c = Canvas({ width = 2, height = 1 })
      local vp = CanvasViewport({ canvas = c, width = 8, height = 8, scale_mode = "stretch" })
      vp:polygon({ points = {{ 0, 0 }, { 6, 0 }, { 0, 6 }} })

      for r = 1, ref.rows do
        for col = 1, ref.cols do
          assert.are.equal(ref.cells[r][col], c.cells[r][col])
        end
      end
    end)


    it("open and fill flags are forwarded to canvas", function()
      local c_open   = Canvas({ width = 2, height = 1 })
      local c_closed = Canvas({ width = 2, height = 1 })
      local vp_open   = CanvasViewport({ canvas = c_open,   width = 4, height = 4, scale_mode = "stretch" })
      local vp_closed = CanvasViewport({ canvas = c_closed, width = 4, height = 4, scale_mode = "stretch" })

      vp_open:polygon({ points   = {{ 0, 0 }, { 3, 0 }, { 0, 3 }}, open = true })
      vp_closed:polygon({ points = {{ 0, 0 }, { 3, 0 }, { 0, 3 }} })

      -- open polygon skips the closing edge so the two canvases differ
      assert.are_not.equal(c_open.cells[1][1], c_closed.cells[1][1])
    end)


    it("empty points draws nothing", function()
      local c = Canvas({ width = 2, height = 1 })
      local vp = CanvasViewport({ canvas = c, width = 4, height = 4, scale_mode = "stretch" })
      vp:polygon({ points = {} })
      assert.are.equal(BLANK, c.cells[1][1])
      assert.are.equal(BLANK, c.cells[1][2])
    end)

  end)



  describe("arc()", function()

    local pi = math.pi

    local function render_lines(c)
      return lines(c:render({ print = true }))
    end


    it("transforms centre and radii into physical pixel space", function()
      -- Canvas 2x1 = 4x4px, virtual 8x8, stretch → sx=sy=0.5
      -- arc at virtual (4,4), rx=2, ry=2, 0..pi/2
      -- physical: centre (2,2), rx=1, ry=1, same angles
      local c = Canvas({ width = 2, height = 1 })
      local vp = CanvasViewport({ canvas = c, width = 8, height = 8, scale_mode = "stretch" })
      vp:arc({ x = 4, y = 4, rx = 2, ry = 2, angle_start = 0, angle_end = pi / 2 })
      assert.are.same({ "⠀⣠" }, render_lines(c))
    end)


    it("angles are not scaled by the scale factor", function()
      -- Canvas 2x1 = 4x4px, virtual 8x8, stretch → sx=sy=0.5
      -- half arc 0..pi: if angles were scaled by sx the arc would be 0..pi/2 and
      -- the left endpoint pixel would be absent; a full half-arc includes it.
      local c = Canvas({ width = 2, height = 1 })
      local vp = CanvasViewport({ canvas = c, width = 8, height = 8, scale_mode = "stretch" })
      vp:arc({ x = 4, y = 4, rx = 2, ry = 2, angle_start = 0, angle_end = pi })
      assert.are.same({ "⠠⣠" }, render_lines(c))
    end)


    it("stretch mode scales rx and ry independently, leaving angles unchanged", function()
      -- Canvas 4x2 = 8x8px, virtual 4x8, stretch → sx=2, sy=1
      -- arc at virtual (2,4), rx=1, ry=1, 0..pi/2
      -- physical: centre (4,4), rx=2, ry=1 — circular arc maps to elliptic arc
      local c = Canvas({ width = 4, height = 2 })
      local vp = CanvasViewport({ canvas = c, width = 4, height = 8, scale_mode = "stretch" })
      vp:arc({ x = 2, y = 4, rx = 1, ry = 1, angle_start = 0, angle_end = pi / 2 })
      assert.are.same(
        { "⠀⠀⠀⠀",
          "⠀⠀⠒⠁" },
        render_lines(c)
      )
    end)


    it("erase flag is forwarded to canvas", function()
      -- Use an inverted canvas so erasing is directly visible as holes in solid background.
      local c = Canvas({ width = 2, height = 1, invert = true })
      local vp = CanvasViewport({ canvas = c, width = 8, height = 8, scale_mode = "stretch" })
      vp:arc({ x = 4, y = 4, rx = 2, ry = 2, angle_start = 0, angle_end = pi / 2, erase = true })
      assert.are.same({ "⣿⠟" }, render_lines(c))
      vp:arc({ x = 4, y = 4, rx = 2, ry = 2, angle_start = 0, angle_end = pi / 2 })
      assert.are.same({ "⣿⣿" }, render_lines(c))
    end)

  end)



  describe("set_canvas()", function()

    it("subsequent draws go to the new canvas", function()
      local c1 = Canvas({ width = 2, height = 1 })
      local vp = CanvasViewport({ canvas = c1, width = 4, height = 4, scale_mode = "stretch" })
      vp:set(0, 0)
      assert.are_not.equal(BLANK, c1.cells[1][1])

      local c2 = Canvas({ width = 2, height = 1 })
      vp:set_canvas(c2)
      vp:set(0, 0)
      assert.are_not.equal(BLANK, c2.cells[1][1])
      -- c1 was not touched by the second set
      assert.are.equal(BLANK, c1.cells[1][2])
    end)


    it("scale factors are recalculated for the new canvas dimensions", function()
      local c1 = Canvas({ width = 2, height = 1 })  -- px: 4x4
      local vp = CanvasViewport({ canvas = c1, width = 4, height = 4, scale_mode = "stretch" })
      local sx1, sy1 = vp:get_scale()
      assert.are.equal(1.0, sx1)
      assert.are.equal(1.0, sy1)

      local c2 = Canvas({ width = 4, height = 2 })  -- px: 8x8
      vp:set_canvas(c2)
      local sx2, sy2 = vp:get_scale()
      assert.are.equal(2.0, sx2)
      assert.are.equal(2.0, sy2)
    end)

  end)

end)
