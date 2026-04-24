local helpers = require "spec.helpers"
local lines = require("pl.stringx").splitlines

-- Mirror of canvas's internal braille() encoder, for computing expected cell values.
-- DOT_BIT (col, row) → bit: (0,0)=1, (0,1)=2, (0,2)=4, (0,3)=64,
--                           (1,0)=8, (1,1)=16, (1,2)=32, (1,3)=128
local function braille(i)
  return string.char(226, 160 + math.floor(i / 64), 128 + (i % 64))
end

local BLANK  = braille(0)    -- U+2800, all dots off
local FILLED = braille(255)  -- U+28FF, all dots on



describe("terminal.ui.canvas", function()

  local Canvas
  local position

  setup(function()
    local terminal = helpers.load()
    Canvas   = require("terminal.ui.canvas")
    position = terminal.cursor.position
  end)


  teardown(function()
    helpers.unload()
  end)



  describe("init()", function()

    it("creates a canvas with valid width and height", function()
      local c = Canvas({ width = 4, height = 3 })
      assert.is_not_nil(c)
      local rows, cols = c:get_size()
      assert.are.equal(3, rows)
      assert.are.equal(4, cols)
    end)


    it("raises an error when width is missing", function()
      assert.has_error(
        function() Canvas({ height = 2 }) end,
        "width and height must be provided"
      )
    end)


    it("raises an error when height is missing", function()
      assert.has_error(
        function() Canvas({ width = 2 }) end,
        "width and height must be provided"
      )
    end)


    it("raises an error when width is not positive", function()
      assert.has_error(function() Canvas({ width =  0, height = 2 }) end)
      assert.has_error(function() Canvas({ width = -1, height = 2 }) end)
    end)


    it("raises an error when height is not positive", function()
      assert.has_error(function() Canvas({ width = 2, height =  0 }) end)
      assert.has_error(function() Canvas({ width = 2, height = -1 }) end)
    end)


    it("exposes pixel dimensions as 2x width and 4x height", function()
      local c = Canvas({ width = 3, height = 2 })
      local ph, pw = c:get_pixels()
      assert.are.equal(3 * 2, pw)  -- 2 pixels per display column
      assert.are.equal(2 * 4, ph)  -- 4 pixels per display row
    end)


    it("defaults to blank (all-dots-off) cells", function()
      local c = Canvas({ width = 3, height = 2 })
      for r = 1, 2 do
        for col = 1, 3 do
          assert.are.equal(BLANK, c.cells[r][col])
        end
      end
    end)


    it("uses filled (all-dots-on) cells when invert option is set", function()
      local c = Canvas({ width = 3, height = 2, invert = true })
      for r = 1, 2 do
        for col = 1, 3 do
          assert.are.equal(FILLED, c.cells[r][col])
        end
      end
    end)

  end)



  describe("set()", function()

    it("illuminates a pixel", function()
      local c = Canvas({ width = 2, height = 1 })
      -- pixel (0,1): col=0, row=1, bit=2 → braille(2)
      c:set(0, 1)
      assert.are.equal(braille(2), c.cells[1][1])
    end)


    it("on an already-set pixel is idempotent", function()
      local c = Canvas({ width = 2, height = 1 })
      c:set(0, 0)
      local after_first = c.cells[1][1]
      c:set(0, 0)
      assert.are.equal(after_first, c.cells[1][1])
    end)


    it("handles the top-left corner pixel (0, 0)", function()
      local c = Canvas({ width = 2, height = 1 })
      -- pixel (0,0): col=0, row=0, bit=1 → braille(1)
      c:set(0, 0)
      assert.are.equal(braille(1), c.cells[1][1])
    end)


    it("handles the bottom-right corner pixel", function()
      local c = Canvas({ width = 2, height = 1 })
      -- px_w=4, px_h=4; bottom-right pixel is (3,3)
      -- cell_col=floor(3/2)+1=2, cell_row=floor(3/4)+1=1
      -- col=3%2=1, row=3%4=3, bit=128 → braille(128)
      c:set(3, 3)
      assert.are.equal(braille(128), c.cells[1][2])
    end)


    it("affects only the correct braille cell", function()
      local c = Canvas({ width = 2, height = 2 })
      -- pixel (0,0) maps to cells[1][1] only
      c:set(0, 0)
      assert.are_not.equal(BLANK, c.cells[1][1])
      assert.are.equal(BLANK, c.cells[1][2])
      assert.are.equal(BLANK, c.cells[2][1])
      assert.are.equal(BLANK, c.cells[2][2])
    end)


    it("ignores pixels outside canvas bounds", function()
      -- 2×1 canvas: valid x=[0,3], valid y=[0,3]
      local c = Canvas({ width = 2, height = 1 })
      assert.has_no_error(function() c:set(-1,  0) end)  -- x too small
      assert.has_no_error(function() c:set( 4,  0) end)  -- x too large
      assert.has_no_error(function() c:set( 0, -1) end)  -- y too small
      assert.has_no_error(function() c:set( 0,  4) end)  -- y too large
      assert.are.equal(BLANK, c.cells[1][1])
      assert.are.equal(BLANK, c.cells[1][2])
    end)

  end)



  describe("unset()", function()

    it("extinguishes a pixel", function()
      local c = Canvas({ width = 2, height = 1 })
      c:set(0, 0)
      assert.are_not.equal(BLANK, c.cells[1][1])
      c:unset(0, 0)
      assert.are.equal(BLANK, c.cells[1][1])
    end)


    it("on an already-unset pixel is idempotent", function()
      local c = Canvas({ width = 2, height = 1 })
      c:unset(0, 0)
      assert.are.equal(BLANK, c.cells[1][1])
    end)


    it("in the same cell as set() is independent per dot", function()
      local c = Canvas({ width = 2, height = 1 })
      -- (0,0): col=0, row=0, bit=1; (1,0): col=1, row=0, bit=8 — same cell (1,1)
      c:set(0, 0)
      c:set(1, 0)
      assert.are.equal(braille(1 + 8), c.cells[1][1])
      c:unset(0, 0)
      assert.are.equal(braille(8), c.cells[1][1])
    end)


    it("ignores pixels outside canvas bounds", function()
      -- 2×1 canvas: valid x=[0,3], valid y=[0,3]; pre-fill to detect unwanted changes
      local c = Canvas({ width = 2, height = 1 })
      c:set(0, 0)
      local before1 = c.cells[1][1]
      local before2 = c.cells[1][2]
      assert.has_no_error(function() c:unset(-1,  0) end)
      assert.has_no_error(function() c:unset( 4,  0) end)
      assert.has_no_error(function() c:unset( 0, -1) end)
      assert.has_no_error(function() c:unset( 0,  4) end)
      assert.are.equal(before1, c.cells[1][1])
      assert.are.equal(before2, c.cells[1][2])
    end)

  end)



  describe("clear()", function()

    it("resets all cells to blank after pixels were set", function()
      local c = Canvas({ width = 3, height = 2 })
      c:set(0, 0)   -- cells[1][1]
      c:set(3, 5)   -- cell_col=2, cell_row=2
      c:clear()
      for r = 1, 2 do
        for col = 1, 3 do
          assert.are.equal(BLANK, c.cells[r][col])
        end
      end
    end)


    it("respects the invert option when clearing", function()
      local c = Canvas({ width = 3, height = 2, invert = true })
      c:unset(0, 0)  -- extinguish one dot from the initially filled cell
      c:clear()
      for r = 1, 2 do
        for col = 1, 3 do
          assert.are.equal(FILLED, c.cells[r][col])
        end
      end
    end)

  end)



  describe("clone()", function()

    it("returns a new canvas with the same dimensions", function()
      local c = Canvas({ width = 3, height = 2 })
      local d = c:clone()
      assert.are.equal(c.cols, d.cols)
      assert.are.equal(c.rows, d.rows)
    end)


    it("cloned canvas has identical cell state", function()
      local c = Canvas({ width = 2, height = 1 })
      c:set(0, 0)
      c:set(3, 3)
      local d = c:clone()
      assert.are.equal(c.cells[1][1], d.cells[1][1])
      assert.are.equal(c.cells[1][2], d.cells[1][2])
    end)


    it("cloned canvas is independent: changes do not affect the original", function()
      local c = Canvas({ width = 2, height = 1 })
      c:set(0, 0)
      local d = c:clone()
      d:unset(0, 0)
      assert.are_not.equal(BLANK, c.cells[1][1])
      assert.are.equal(BLANK, d.cells[1][1])
    end)


    it("preserves the invert option", function()
      local c = Canvas({ width = 1, height = 1, invert = true })
      local d = c:clone()
      assert.are.equal(c._blank, d._blank)
    end)

  end)



  describe("resize()", function()

    it("reports the new size via get_size()", function()
      local c = Canvas({ width = 2, height = 2 })
      c:resize(4, 5)
      local rows, cols = c:get_size()
      assert.are.equal(4, rows)
      assert.are.equal(5, cols)
    end)


    it("updates pixel dimensions via get_pixels()", function()
      local c = Canvas({ width = 2, height = 2 })
      c:resize(3, 4)
      local ph, pw = c:get_pixels()
      assert.are.equal(3 * 4, ph)
      assert.are.equal(4 * 2, pw)
    end)


    it("growing rows adds blank rows at the bottom", function()
      local c = Canvas({ width = 1, height = 1 })
      c:resize(3, 1)
      assert.are.equal(BLANK, c.cells[2][1])
      assert.are.equal(BLANK, c.cells[3][1])
    end)


    it("growing cols adds blank cells to the right of every row", function()
      local c = Canvas({ width = 1, height = 2 })
      c:resize(2, 3)
      for r = 1, 2 do
        assert.are.equal(BLANK, c.cells[r][2])
        assert.are.equal(BLANK, c.cells[r][3])
      end
    end)


    it("shrinking rows removes rows from the bottom", function()
      local c = Canvas({ width = 1, height = 3 })
      c:resize(1, 1)
      assert.is_nil(c.cells[2])
      assert.is_nil(c.cells[3])
    end)


    it("shrinking cols removes cells from the right of every row", function()
      local c = Canvas({ width = 3, height = 2 })
      c:resize(2, 1)
      for r = 1, 2 do
        assert.is_nil(c.cells[r][2])
        assert.is_nil(c.cells[r][3])
      end
    end)


    it("preserves existing content within the new bounds", function()
      local c = Canvas({ width = 3, height = 3 })
      c:set(0, 0)  -- cells[1][1]
      c:set(1, 1)  -- cells[1][1] (same cell, different dot)
      local original = c.cells[1][1]
      c:resize(2, 2)
      assert.are.equal(original, c.cells[1][1])
    end)


    it("new cells respect the invert option", function()
      local c = Canvas({ width = 1, height = 1, invert = true })
      c:resize(2, 2)
      assert.are.equal(FILLED, c.cells[1][2])
      assert.are.equal(FILLED, c.cells[2][1])
      assert.are.equal(FILLED, c.cells[2][2])
    end)


    it("same dimensions is a no-op", function()
      local c = Canvas({ width = 2, height = 2 })
      c:set(0, 0)
      local before = c.cells[1][1]
      c:resize(2, 2)
      local rows, cols = c:get_size()
      assert.are.equal(2, rows)
      assert.are.equal(2, cols)
      assert.are.equal(before, c.cells[1][1])
    end)


    it("errors when rows is not positive", function()
      local c = Canvas({ width = 2, height = 2 })
      assert.has_error(function() c:resize( 0, 2) end)
      assert.has_error(function() c:resize(-1, 2) end)
    end)


    it("errors when cols is not positive", function()
      local c = Canvas({ width = 2, height = 2 })
      assert.has_error(function() c:resize(2,  0) end)
      assert.has_error(function() c:resize(2, -1) end)
    end)

  end)



  describe("scroll()", function()

    it("shifts content down, blanking the vacated top rows", function()
      local c = Canvas({ width = 1, height = 2 })
      c:set(0, 0)  -- cells[1][1]
      local original = c.cells[1][1]
      c:scroll(1, 0)
      assert.are.equal(BLANK,    c.cells[1][1])  -- vacated
      assert.are.equal(original, c.cells[2][1])  -- content moved down
    end)


    it("shifts content up, blanking the vacated bottom rows", function()
      local c = Canvas({ width = 1, height = 2 })
      c:set(0, 4)  -- y=4 → cell_row=2; cells[2][1]
      local original = c.cells[2][1]
      c:scroll(-1, 0)
      assert.are.equal(original, c.cells[1][1])  -- content moved up
      assert.are.equal(BLANK,    c.cells[2][1])  -- vacated
    end)


    it("shifts content right, blanking the vacated left cols", function()
      local c = Canvas({ width = 2, height = 1 })
      c:set(0, 0)  -- cells[1][1]
      local original = c.cells[1][1]
      c:scroll(0, 1)
      assert.are.equal(BLANK,    c.cells[1][1])  -- vacated
      assert.are.equal(original, c.cells[1][2])  -- content moved right
    end)


    it("shifts content left, blanking the vacated right cols", function()
      local c = Canvas({ width = 2, height = 1 })
      c:set(2, 0)  -- x=2 → cell_col=2; cells[1][2]
      local original = c.cells[1][2]
      c:scroll(0, -1)
      assert.are.equal(original, c.cells[1][1])  -- content moved left
      assert.are.equal(BLANK,    c.cells[1][2])  -- vacated
    end)


    it("row shift >= height clears all rows", function()
      local c = Canvas({ width = 1, height = 2 })
      c:set(0, 0)
      c:set(0, 4)
      c:scroll(2, 0)
      assert.are.equal(BLANK, c.cells[1][1])
      assert.are.equal(BLANK, c.cells[2][1])
    end)


    it("col shift >= width clears all cols", function()
      local c = Canvas({ width = 2, height = 1 })
      c:set(0, 0)
      c:set(2, 0)
      c:scroll(0, 2)
      assert.are.equal(BLANK, c.cells[1][1])
      assert.are.equal(BLANK, c.cells[1][2])
    end)


    it("applies row and col shifts together", function()
      local c = Canvas({ width = 2, height = 2 })
      c:set(0, 0)  -- cells[1][1]
      local original = c.cells[1][1]
      c:scroll(1, 1)
      assert.are.equal(BLANK,    c.cells[1][1])
      assert.are.equal(BLANK,    c.cells[1][2])
      assert.are.equal(BLANK,    c.cells[2][1])
      assert.are.equal(original, c.cells[2][2])  -- moved down+right
    end)


    it("scroll(0, 0) is a no-op", function()
      local c = Canvas({ width = 2, height = 2 })
      c:set(0, 0)
      local before = c.cells[1][1]
      c:scroll(0, 0)
      assert.are.equal(before, c.cells[1][1])
    end)


    it("does not change canvas dimensions", function()
      local c = Canvas({ width = 3, height = 2 })
      c:scroll(1, 1)
      local rows, cols = c:get_size()
      assert.are.equal(2, rows)
      assert.are.equal(3, cols)
    end)

  end)



  describe("roll()", function()

    it("rolls content down, wrapping the bottom row to the top", function()
      local c = Canvas({ width = 1, height = 2 })
      c:set(0, 4)  -- y=4 → cell_row=2; cells[2][1]
      local original = c.cells[2][1]
      c:roll(1, 0)
      assert.are.equal(original, c.cells[1][1])  -- wrapped to top
      assert.are.equal(BLANK,    c.cells[2][1])  -- moved up (was blank)
    end)


    it("rolls content up, wrapping the top row to the bottom", function()
      local c = Canvas({ width = 1, height = 2 })
      c:set(0, 0)  -- cells[1][1]
      local original = c.cells[1][1]
      c:roll(-1, 0)
      assert.are.equal(BLANK,    c.cells[1][1])  -- moved down (was blank)
      assert.are.equal(original, c.cells[2][1])  -- wrapped to bottom
    end)


    it("rolls content right, wrapping the last col to the left", function()
      local c = Canvas({ width = 2, height = 1 })
      c:set(2, 0)  -- x=2 → cell_col=2; cells[1][2]
      local original = c.cells[1][2]
      c:roll(0, 1)
      assert.are.equal(original, c.cells[1][1])  -- wrapped to left
      assert.are.equal(BLANK,    c.cells[1][2])  -- moved right (was blank)
    end)


    it("rolls content left, wrapping the first col to the right", function()
      local c = Canvas({ width = 2, height = 1 })
      c:set(0, 0)  -- cells[1][1]
      local original = c.cells[1][1]
      c:roll(0, -1)
      assert.are.equal(BLANK,    c.cells[1][1])  -- moved left (was blank)
      assert.are.equal(original, c.cells[1][2])  -- wrapped to right
    end)


    it("rolling by the canvas height is a no-op", function()
      local c = Canvas({ width = 1, height = 2 })
      c:set(0, 0)
      local before = c.cells[1][1]
      c:roll(2, 0)
      assert.are.equal(before, c.cells[1][1])
    end)


    it("rolling by the canvas width is a no-op", function()
      local c = Canvas({ width = 2, height = 1 })
      c:set(0, 0)
      local before = c.cells[1][1]
      c:roll(0, 2)
      assert.are.equal(before, c.cells[1][1])
    end)


    it("roll(0, 0) is a no-op", function()
      local c = Canvas({ width = 2, height = 2 })
      c:set(0, 0)
      local before = c.cells[1][1]
      c:roll(0, 0)
      assert.are.equal(before, c.cells[1][1])
    end)


    it("applies row and col rolls together", function()
      local c = Canvas({ width = 2, height = 2 })
      c:set(0, 0)  -- cells[1][1]
      local original = c.cells[1][1]
      c:roll(1, 1)
      assert.are.equal(original, c.cells[2][2])  -- wrapped down+right
    end)


    it("does not change canvas dimensions", function()
      local c = Canvas({ width = 3, height = 2 })
      c:roll(1, 1)
      local rows, cols = c:get_size()
      assert.are.equal(2, rows)
      assert.are.equal(3, cols)
    end)

  end)



  describe("render()", function()

    it("returns a string", function()
      local c = Canvas({ width = 2, height = 1 })
      assert.is_string(c:render())
    end)


    it("a freshly created canvas renders all blank cells", function()
      -- 1×1: _seq_return = left_seq(1)+up_seq(0); up_seq(0) is empty
      local c = Canvas({ width = 1, height = 1 })
      local expected = BLANK .. position.left_seq(1)
      assert.are.equal(expected, c:render())
    end)


    it("a fully set canvas renders all filled cells", function()
      -- 1×1: set all 8 pixels (2 px-cols × 4 px-rows)
      local c = Canvas({ width = 1, height = 1 })
      for x = 0, 1 do
        for y = 0, 3 do
          c:set(x, y)
        end
      end
      local expected = FILLED .. position.left_seq(1)
      assert.are.equal(expected, c:render())
    end)


    it("cursor ends at the top-left of the canvas after render", function()
      -- 2×2: _seq_return = left_seq(2)+up_seq(1)
      local c = Canvas({ width = 2, height = 2 })
      local return_seq = position.left_seq(2) .. position.up_seq(1)
      local result = c:render()
      assert.are.equal(return_seq, result:sub(-#return_seq))
    end)


    it("render reflects set pixels correctly", function()
      -- 1×1: set (0,0) col=0,row=0,bit=1 → braille(1)
      local c = Canvas({ width = 1, height = 1 })
      c:set(0, 0)
      assert.are.equal(braille(1) .. position.left_seq(1), c:render())
    end)


    it("render reflects unset pixels correctly", function()
      -- 1×1: set then unset (0,0) → back to BLANK
      local c = Canvas({ width = 1, height = 1 })
      c:set(0, 0)
      c:unset(0, 0)
      assert.are.equal(BLANK .. position.left_seq(1), c:render())
    end)


    describe("print mode", function()

      it("separates rows with newlines instead of cursor movements", function()
        -- 2×2: expect row1_cells + "\n" + row2_cells, no escape sequences
        local c = Canvas({ width = 2, height = 2 })
        local expected = BLANK .. BLANK .. "\n" .. BLANK .. BLANK
        assert.are.equal(expected, c:render({ print = true }))
      end)


      it("does not append a trailing newline after the last row", function()
        local c = Canvas({ width = 2, height = 2 })
        local result = c:render({ print = true })
        assert.are_not.equal("\n", result:sub(-1))
      end)


      it("emits no cursor-movement sequences", function()
        local c = Canvas({ width = 2, height = 2 })
        local result = c:render({ print = true })
        -- stripping ANSI sequences from a clean output leaves it unchanged
        assert.are.equal(result, require("terminal").utils.strip_ansi(result))
      end)

    end)


    describe("viewport option", function()

      it("renders only the specified columns", function()
        -- 3×1: set a pixel in cell[1][1]; render only the middle cell (col 2)
        local c = Canvas({ width = 3, height = 1 })
        c:set(0, 0)  -- sets cell[1][1] to braille(1); cell[1][2] stays BLANK
        local result = c:render({ col = 2, cols = 1 })
        assert.are.equal(BLANK .. position.left_seq(1), result)
      end)


      it("renders only the specified rows", function()
        -- 1×3: set a pixel in row 1; render only rows 2-3 (both BLANK)
        local c = Canvas({ width = 1, height = 3 })
        c:set(0, 0)  -- sets cell[1][1]; cells[2][1] and [3][1] stay BLANK
        local seq_between = position.down_seq(1) .. position.left_seq(1)
        local seq_return  = position.left_seq(1) .. position.up_seq(1)
        local expected = BLANK .. seq_between .. BLANK .. seq_return
        assert.are.equal(expected, c:render({ row = 2, rows = 2 }))
      end)


      it("cursor sequences are sized for the viewport, not the full canvas", function()
        -- 3×3 canvas, render 2×2 viewport
        local c = Canvas({ width = 3, height = 3 })
        local result = c:render({ row = 2, col = 2, rows = 2, cols = 2 })
        local seq_return = position.left_seq(2) .. position.up_seq(1)
        assert.are.equal(seq_return, result:sub(-#seq_return))
      end)


      it("viewport with print mode renders only viewport cells with newlines", function()
        -- 3×2 canvas, render cols 2-3 of both rows
        local c = Canvas({ width = 3, height = 2 })
        local result = c:render({ col = 2, cols = 2, print = true })
        assert.are.equal(BLANK .. BLANK .. "\n" .. BLANK .. BLANK, result)
      end)


      it("omitting viewport renders the full canvas", function()
        local c = Canvas({ width = 2, height = 2 })
        assert.are.equal(c:render(), c:render({}))
      end)


      it("errors when row is out of bounds", function()
        local c = Canvas({ width = 2, height = 2 })
        assert.has_error(function() c:render({ row = 0 }) end)
        assert.has_error(function() c:render({ row = 2, rows = 2 }) end)  -- r2 = 3 > self.rows
      end)


      it("errors when col is out of bounds", function()
        local c = Canvas({ width = 2, height = 2 })
        assert.has_error(function() c:render({ col = 0 }) end)
        assert.has_error(function() c:render({ col = 2, cols = 2 }) end)  -- c2 = 3 > self.cols
      end)

    end)

  end)



  describe("get_pixels()", function()

    it("returns pixel height and width as 4*rows and 2*cols", function()
      local c = Canvas({ width = 3, height = 2 })
      local ph, pw = c:get_pixels()
      assert.are.equal(2 * 4, ph)  -- height * 4, returned first
      assert.are.equal(3 * 2, pw)  -- width * 2, returned second
    end)

  end)



  describe("get_size()", function()

    it("returns rows and columns matching the init options", function()
      local c = Canvas({ width = 5, height = 3 })
      local rows, cols = c:get_size()
      assert.are.equal(3, rows)
      assert.are.equal(5, cols)
    end)

  end)



  describe("drawing", function()

    describe("line()", function()

      it("draws a horizontal line", function()
        -- (0,0)→(3,0): pixels (0,0),(1,0) in cell (1,1); (2,0),(3,0) in cell (1,2)
        -- col=0,row=0,bit=1 and col=1,row=0,bit=8 → braille(1+8) in each cell
        local c = Canvas({ width = 2, height = 1 })
        c:line({ x1 = 0, y1 = 0, x2 = 3, y2 = 0 })
        assert.are.equal(braille(1 + 8), c.cells[1][1])
        assert.are.equal(braille(1 + 8), c.cells[1][2])
      end)


      it("draws a vertical line", function()
        -- (0,0)→(0,7): col=0, all 4 left-column bits set in each of 2 cell rows
        -- bits 1+2+4+64 = 71 (rows 0-3 of the left dot column)
        local c = Canvas({ width = 1, height = 2 })
        c:line({ x1 = 0, y1 = 0, x2 = 0, y2 = 7 })
        assert.are.equal(braille(1 + 2 + 4 + 64), c.cells[1][1])
        assert.are.equal(braille(1 + 2 + 4 + 64), c.cells[2][1])
      end)


      it("draws a diagonal line", function()
        -- (0,0)→(3,3): Bresenham gives (0,0),(1,1),(2,2),(3,3)
        -- cells[1][1]: (0,0)=bit1, (1,1)=bit16 → braille(17)
        -- cells[1][2]: (2,2)=bit4, (3,3)=bit128 → braille(132)
        local c = Canvas({ width = 2, height = 1 })
        c:line({ x1 = 0, y1 = 0, x2 = 3, y2 = 3 })
        assert.are.equal(braille(1 + 16),  c.cells[1][1])
        assert.are.equal(braille(4 + 128), c.cells[1][2])
      end)


      it("draws the same pixels regardless of direction", function()
        -- (3,3)→(0,0) must produce identical cells to (0,0)→(3,3)
        local forward  = Canvas({ width = 2, height = 1 })
        local reversed = Canvas({ width = 2, height = 1 })
        forward:line({ x1 = 0, y1 = 0, x2 = 3, y2 = 3 })
        reversed:line({ x1 = 3, y1 = 3, x2 = 0, y2 = 0 })
        assert.are.equal(forward.cells[1][1], reversed.cells[1][1])
        assert.are.equal(forward.cells[1][2], reversed.cells[1][2])
      end)


      it("draws a single-pixel line (x1==x2, y1==y2)", function()
        -- (0,0)→(0,0): only pixel (0,0), col=0,row=0,bit=1 → braille(1)
        local c = Canvas({ width = 1, height = 1 })
        c:line({ x1 = 0, y1 = 0, x2 = 0, y2 = 0 })
        assert.are.equal(braille(1), c.cells[1][1])
      end)


      it("erases pixels when the erase flag is set", function()
        local c = Canvas({ width = 2, height = 1 })
        c:line({ x1 = 0, y1 = 0, x2 = 3, y2 = 0 })
        assert.are_not.equal(BLANK, c.cells[1][1])
        assert.are_not.equal(BLANK, c.cells[1][2])
        c:line({ x1 = 0, y1 = 0, x2 = 3, y2 = 0, erase = true })
        assert.are.equal(BLANK, c.cells[1][1])
        assert.are.equal(BLANK, c.cells[1][2])
      end)


      it("ignores the out-of-bounds portion of a line", function()
        -- line from inside to well outside; in-bounds pixels must be set, no error
        local c = Canvas({ width = 1, height = 1 })
        assert.has_no_error(function() c:line({ x1 = 0, y1 = 0, x2 = 20, y2 = 20 }) end)
        -- pixel (0,0) is in-bounds and must be set
        assert.are_not.equal(BLANK, c.cells[1][1])
      end)

    end)



    describe("circle()", function()

      it("handles radius zero (single pixel)", function()
        -- circle(cx=0,cy=0,r=0) on 1×1: only pixel (0,0), col=0,row=0,bit=1
        local c = Canvas({ width = 1, height = 1 })
        c:circle({ x = 0, y = 0, r = 0 })
        assert.are.equal(braille(1), c.cells[1][1])
      end)


      it("draws a circle outline", function()
        -- circle(cx=2,cy=4,r=1) on 3×2 (px_w=6,px_h=8); center at cells[2][2]
        local c = Canvas({ width = 3, height = 2 })
        c:circle({ x = 2, y = 4, r = 1 })
        assert.are.equal(braille( 0), c.cells[1][1])
        assert.are.equal(braille(64), c.cells[1][2])
        assert.are.equal(braille( 0), c.cells[1][3])
        assert.are.equal(braille( 8), c.cells[2][1])
        assert.are.equal(braille(10), c.cells[2][2])
        assert.are.equal(braille( 0), c.cells[2][3])
      end)


      it("fills a circle when fill is true", function()
        -- same as outline but center cell gains the interior pixel (2,4)→bit=1: 10+1=11
        local c = Canvas({ width = 3, height = 2 })
        c:circle({ x = 2, y = 4, r = 1, fill = true })
        assert.are.equal(braille( 0), c.cells[1][1])
        assert.are.equal(braille(64), c.cells[1][2])
        assert.are.equal(braille( 0), c.cells[1][3])
        assert.are.equal(braille( 8), c.cells[2][1])
        assert.are.equal(braille(11), c.cells[2][2])  -- center pixel added
        assert.are.equal(braille( 0), c.cells[2][3])
      end)


      it("erases pixels when the erase flag is set", function()
        local c = Canvas({ width = 3, height = 2 })
        c:circle({ x = 2, y = 4, r = 1 })
        c:circle({ x = 2, y = 4, r = 1, erase = true })
        for r = 1, 2 do
          for col = 1, 3 do
            assert.are.equal(BLANK, c.cells[r][col])
          end
        end
      end)


      it("ignores out-of-bounds pixels when circle extends beyond canvas edge", function()
        -- circle centred near edge so part of the outline falls outside
        local c = Canvas({ width = 2, height = 2 })
        assert.has_no_error(function() c:circle({ x = 0, y = 0, r = 3 }) end)
      end)

    end)



    describe("arc()", function()

      -- Helper: render canvas to a table of braille-string lines.
      local function render_lines(c)
        return lines(c:render({ print = true }))
      end

      local pi = math.pi


      it("draws a single pixel when rx and ry are both zero", function()
        -- rx=ry=0: degenerate point at (cx, cy) regardless of angles.
        -- cx=0,cy=0 on 1×1 canvas: pixel (0,0) → col=0,row=0,bit=1 → ⠁
        local c = Canvas({ width = 1, height = 1 })
        c:arc({ x = 0, y = 0, rx = 0, ry = 0, angle_start = 0, angle_end = 0 })
        assert.are.same({ "⠁" }, render_lines(c))
      end)


      it("always plots the start-angle pixel", function()
        -- angle_start = angle_end = 0: arc degenerates to a single point.
        -- cx=4, cy=4, r=4 on 5×3 canvas (px_w=10, px_h=12).
        -- At θ=0: x=floor(4+4+0.5)=8, y=4 → cell[2][5], dot_col=0,row=0, bit=1 → ⠁
        local c = Canvas({ width = 5, height = 3 })
        c:arc({ x = 4, y = 4, rx = 4, ry = 4, angle_start = 0, angle_end = 0 })
        assert.are.same(
          { "⠀⠀⠀⠀⠀",
            "⠀⠀⠀⠀⠁",
            "⠀⠀⠀⠀⠀" },
          render_lines(c)
        )
      end)


      it("always plots the end-angle pixel", function()
        -- angle_start = angle_end = pi/2: arc degenerates to a single point at the bottom.
        -- At θ=pi/2: x=4, y=floor(4+4+0.5)=8 → cell[3][3], dot_col=0,row=0, bit=1 → ⠁
        local c = Canvas({ width = 5, height = 3 })
        c:arc({ x = 4, y = 4, rx = 4, ry = 4, angle_start = pi/2, angle_end = pi/2 })
        assert.are.same(
          { "⠀⠀⠀⠀⠀",
            "⠀⠀⠀⠀⠀",
            "⠀⠀⠁⠀⠀" },
          render_lines(c)
        )
      end)


      it("a full revolution produces the expected closed outline", function()
        -- cx=4, cy=4, r=4 on 5×3 canvas; one full revolution via parametric walk.
        local c = Canvas({ width = 5, height = 3 })
        c:arc({ x = 4, y = 4, rx = 4, ry = 4, angle_start = 0, angle_end = 2*pi })
        assert.are.same(
          { "⡰⠉⠉⠲⡀",
            "⢧⠀⠀⣀⠇",
            "⠀⠉⠉⠀⠀" },
          render_lines(c)
        )
      end)


      it("a quarter arc (pi/2) only sets pixels in the expected quadrant", function()
        -- 0..pi/2 sweeps clockwise from the right to the bottom of the circle.
        -- All pixels lie in the bottom-right quadrant of the canvas; the top row
        -- and the left two columns stay entirely blank.
        -- cx=4, cy=4, r=4 on 5×3 canvas.
        local c = Canvas({ width = 5, height = 3 })
        c:arc({ x = 4, y = 4, rx = 4, ry = 4, angle_start = 0, angle_end = pi/2 })
        assert.are.same(
          { "⠀⠀⠀⠀⠀",
            "⠀⠀⠀⣀⠇",
            "⠀⠀⠉⠀⠀" },
          render_lines(c)
        )
      end)


      it("a half arc (pi) only sets pixels on one side of the centre", function()
        -- 0..pi sweeps the bottom half of the circle; the top row is entirely blank.
        -- cx=4, cy=4, r=4 on 5×3 canvas.
        local c = Canvas({ width = 5, height = 3 })
        c:arc({ x = 4, y = 4, rx = 4, ry = 4, angle_start = 0, angle_end = pi })
        assert.are.same(
          { "⠀⠀⠀⠀⠀",
            "⢧⠀⠀⣀⠇",
            "⠀⠉⠉⠀⠀" },
          render_lines(c)
        )
      end)


      it("rx=0 draws a vertical segment for the given angle range", function()
        -- rx=0 forces x=cx for every angle; only ry*sin(θ) varies.
        -- cx=2, cy=6, ry=4 on 2×3 canvas (px_h=12); arc from -pi/2 to pi/2
        -- spans y=6-4=2 to y=6+4=10 at x=2 (right column, cell_col=2).
        -- row1[2]: y=2(bit4)+y=3(bit64)=68 → ⡄
        -- row2[2]: y=4(bit1)+y=5(bit2)+y=6(bit4)+y=7(bit64)=71 → ⡇
        -- row3[2]: y=8(bit1)+y=9(bit2)+y=10(bit4)=7 → ⠇
        local c = Canvas({ width = 2, height = 3 })
        c:arc({ x = 2, y = 6, rx = 0, ry = 4, angle_start = -pi/2, angle_end = pi/2 })
        assert.are.same(
          { "⠀⡄",
            "⠀⡇",
            "⠀⠇" },
          render_lines(c)
        )
      end)


      it("ry=0 draws a horizontal segment for the given angle range", function()
        -- ry=0 forces y=cy for every angle; only rx*cos(θ) varies.
        -- cx=4, cy=2, rx=4 on 3×1 canvas (px_w=6); arc from -pi to 0
        -- spans x=4-4=0 to x=4+4=8 at y=2, clipped to x=0..5.
        -- All three cells: y=2 → cell_row=1, dot_row=2; left bit=4, right bit=32;
        -- each cell has bits 4+32=36 → ⠤
        local c = Canvas({ width = 3, height = 1 })
        c:arc({ x = 4, y = 2, rx = 4, ry = 0, angle_start = -pi, angle_end = 0 })
        assert.are.same({ "⠤⠤⠤" }, render_lines(c))
      end)


      it("erases pixels when the erase flag is set", function()
        -- Use an inverted canvas (starts fully lit) so that erasing the arc cuts
        -- visible holes in the solid background, making the effect directly observable.
        -- Restoring with a plain arc fills the holes and returns the canvas to all-lit.
        local c = Canvas({ width = 5, height = 3, invert = true })
        c:arc({ x = 4, y = 4, rx = 4, ry = 4, angle_start = 0, angle_end = pi/2, erase = true })
        assert.are.same(
          { "⣿⣿⣿⣿⣿",
            "⣿⣿⣿⠿⣸",
            "⣿⣿⣶⣿⣿" },
          render_lines(c)
        )
        c:arc({ x = 4, y = 4, rx = 4, ry = 4, angle_start = 0, angle_end = pi/2 })
        assert.are.same(
          { "⣿⣿⣿⣿⣿",
            "⣿⣿⣿⣿⣿",
            "⣿⣿⣿⣿⣿" },
          render_lines(c)
        )
      end)


      it("ignores out-of-bounds pixels when the arc extends beyond the canvas edge", function()
        -- Circle centred at the top-left corner so most of it falls outside.
        -- No error; the in-bounds pixels are still drawn.
        local c = Canvas({ width = 2, height = 2 })
        assert.has_no_error(function()
          c:arc({ x = 0, y = 0, rx = 4, ry = 4, angle_start = 0, angle_end = 2*pi })
        end)
        assert.are.same(
          { "⠀⣀",
            "⠉⠀" },
          render_lines(c)
        )
      end)


      it("errors when angle_end is less than angle_start", function()
        local c = Canvas({ width = 2, height = 2 })
        assert.has_error(
          function() c:arc({ x = 2, y = 4, rx = 2, ry = 2, angle_start = pi, angle_end = 0 }) end,
          "angle_end must be >= angle_start"
        )
      end)


      it("errors when rx or ry is negative", function()
        -- negative radii produce a non-positive step denominator, causing an infinite loop
        local c = Canvas({ width = 2, height = 2 })
        assert.has_error(
          function() c:arc({ x = 2, y = 2, rx = -1, ry =  1, angle_start = 0, angle_end = pi }) end,
          "rx and ry must be >= 0"
        )
        assert.has_error(
          function() c:arc({ x = 2, y = 2, rx =  1, ry = -1, angle_start = 0, angle_end = pi }) end,
          "rx and ry must be >= 0"
        )
        assert.has_error(
          function() c:arc({ x = 2, y = 2, rx = -1, ry = -1, angle_start = 0, angle_end = pi }) end,
          "rx and ry must be >= 0"
        )
      end)

    end)



    describe("polygon()", function()

      it("draws nothing for an empty points table", function()
        local c = Canvas({ width = 2, height = 1 })
        c:polygon({ points = {} })
        assert.are.equal(BLANK, c.cells[1][1])
        assert.are.equal(BLANK, c.cells[1][2])
      end)


      it("draws a single dot for one point", function()
        -- polygon({points={{0,0}}}) on 1×1: pixel (0,0), col=0,row=0,bit=1
        local c = Canvas({ width = 1, height = 1 })
        c:polygon({ points = {{ 0, 0 }} })
        assert.are.equal(braille(1), c.cells[1][1])
      end)


      it("draws a line for two points", function()
        -- polygon({points={{0,0},{3,0}}}) = horizontal line, same as line() test
        local c = Canvas({ width = 2, height = 1 })
        c:polygon({ points = {{ 0, 0 }, { 3, 0 }} })
        assert.are.equal(braille(9), c.cells[1][1])
        assert.are.equal(braille(9), c.cells[1][2])
      end)


      it("draws a closed triangle outline for three points", function()
        -- triangle (0,0),(3,0),(0,3) on 2×1; interior pixel (1,1) NOT set
        local c = Canvas({ width = 2, height = 1 })
        c:polygon({ points = {{ 0, 0 }, { 3, 0 }, { 0, 3 }} })
        assert.are.equal(braille(111), c.cells[1][1])
        assert.are.equal(braille( 11), c.cells[1][2])
      end)


      it("fills a polygon when fill is true", function()
        -- same triangle; interior pixel (1,1)→bit=16 added: 111+16=127
        local c = Canvas({ width = 2, height = 1 })
        c:polygon({ points = {{ 0, 0 }, { 3, 0 }, { 0, 3 }}, fill = true })
        assert.are.equal(braille(127), c.cells[1][1])
        assert.are.equal(braille( 11), c.cells[1][2])
      end)


      it("erases pixels when the erase flag is set", function()
        local c = Canvas({ width = 2, height = 1 })
        c:polygon({ points = {{ 0, 0 }, { 3, 0 }, { 0, 3 }} })
        c:polygon({ points = {{ 0, 0 }, { 3, 0 }, { 0, 3 }}, erase = true })
        assert.are.equal(BLANK, c.cells[1][1])
        assert.are.equal(BLANK, c.cells[1][2])
      end)


      it("ignores out-of-bounds pixels when polygon extends beyond canvas edge", function()
        -- triangle with one vertex well outside the canvas
        local c = Canvas({ width = 1, height = 1 })
        assert.has_no_error(function() c:polygon({ points = {{ 0, 0 }, { 20, 0 }, { 0, 20 }} }) end)
        -- the in-bounds vertex (0,0) must still be drawn
        assert.are_not.equal(BLANK, c.cells[1][1])
      end)


      it("open=true does not draw the closing edge", function()
        -- triangle (0,0),(3,0),(0,3): closed draws 3 edges; open draws only 2
        local closed = Canvas({ width = 2, height = 1 })
        closed:polygon({ points = {{ 0, 0 }, { 3, 0 }, { 0, 3 }} })

        local opened = Canvas({ width = 2, height = 1 })
        opened:polygon({ points = {{ 0, 0 }, { 3, 0 }, { 0, 3 }}, open = true })

        -- the closing edge (0,3)→(0,0) sets pixels in cell[1][1] that open skips
        assert.are_not.equal(closed.cells[1][1], opened.cells[1][1])
      end)


      it("open=true with two points draws a single line (same as closed)", function()
        -- for 2 points open and closed are identical: one segment
        local c_open   = Canvas({ width = 2, height = 1 })
        local c_closed = Canvas({ width = 2, height = 1 })
        c_open:polygon({ points = {{ 0, 0 }, { 3, 0 }}, open = true })
        c_closed:polygon({ points = {{ 0, 0 }, { 3, 0 }} })
        assert.are.equal(c_closed.cells[1][1], c_open.cells[1][1])
        assert.are.equal(c_closed.cells[1][2], c_open.cells[1][2])
      end)


      it("errors when open and fill are both true", function()
        local c = Canvas({ width = 2, height = 1 })
        assert.has_error(function()
          c:polygon({ points = {{ 0, 0 }, { 3, 0 }, { 0, 3 }}, open = true, fill = true })
        end)
      end)

    end)

  end)

end)
