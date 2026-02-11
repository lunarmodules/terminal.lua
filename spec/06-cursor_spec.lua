local helpers = require "spec.helpers"


describe("Cursor", function()

  local terminal, cursor

  before_each(function()
    terminal = helpers.load()
    cursor = terminal.cursor
  end)


  after_each(function()
    helpers.unload()
  end)



  describe("visible.set()", function()

    it("returns ANSI sequence for hiding the cursor", function()
      assert.are.equal("\27[?25l", cursor.visible.set_seq(false))
    end)


    it("returns ANSI sequence for showing the cursor", function()
      assert.are.equal("\27[?25h", cursor.visible.set_seq(true))
    end)


    it("defaults to true", function()
      assert.are.equal(cursor.visible.set_seq(true), cursor.visible.set_seq())
    end)

  end)



  describe("visible.stack.apply_seq()", function()

    it("returns ANSI sequence for showing the cursor upon start", function()
      assert.are.equal("\27[?25h", cursor.visible.stack.apply_seq())
    end)


    it("returns ANSI sequence for showing/hiding the cursor", function()
      cursor.visible.stack.push_seq(false)
      assert.are.equal("\27[?25l", cursor.visible.stack.apply_seq())
      cursor.visible.stack.push_seq(true)
      assert.are.equal("\27[?25h", cursor.visible.stack.apply_seq())
    end)

  end)



  describe("visible.stack.pushs()", function()

    it("returns ANSI sequence for hiding the cursor", function()
      assert.are.equal("\27[?25l", cursor.visible.stack.push_seq(false))
    end)


    it("returns ANSI sequence for showing the cursor", function()
      assert.are.equal("\27[?25h", cursor.visible.stack.push_seq(true))
    end)

  end)



  describe("visible.stack.pops()", function()

    it("returns ANSI sequence at the top of the stack", function()
      cursor.visible.stack.push_seq(false)
      cursor.visible.stack.push_seq(true)
      assert.are.equal("\27[?25l", cursor.visible.stack.pop_seq())
      assert.are.equal("\27[?25h", cursor.visible.stack.pop_seq())
    end)


    it("pops multiple items at once", function()
      cursor.visible.stack.push_seq(false)
      cursor.visible.stack.push_seq(true)
      cursor.visible.stack.push_seq(true)
      cursor.visible.stack.push_seq(true)
      cursor.visible.stack.push_seq(true)
      assert.are.equal("\27[?25l", cursor.visible.stack.pop_seq(4))
    end)


    it("over-popping ends with the last item", function()
      cursor.visible.stack.push_seq(false)
      cursor.visible.stack.push_seq(false)
      cursor.visible.stack.push_seq(false)
      cursor.visible.stack.push_seq(false)
      assert.are.equal("\27[?25h", cursor.visible.stack.pop_seq(math.huge))
    end)

  end)



  describe("shape.set()", function()

    it("returns ANSI sequence for setting the cursor shape", function()
      assert.are.equal("\27[2 q", cursor.shape.set_seq("block"))
      assert.are.equal("\27[1 q", cursor.shape.set_seq("block_blink"))
      assert.are.equal("\27[4 q", cursor.shape.set_seq("underline"))
      assert.are.equal("\27[3 q", cursor.shape.set_seq("underline_blink"))
      assert.are.equal("\27[6 q", cursor.shape.set_seq("bar"))
      assert.are.equal("\27[5 q", cursor.shape.set_seq("bar_blink"))
    end)


    it("returns a descriptive error on a bad shape", function()
      assert.has.error(function()
        cursor.shape.set_seq(true)
      end, 'Invalid cursor shape: "true". Expected one of: "bar", "bar_blink", "block", "block_blink", "underline", "underline_blink"')
    end)

  end)



  describe("shape.stack.apply_seq()", function()

    it("returns ANSI sequence for resetting the cursor shape upon start", function()
      assert.are.equal("\27[0 q", cursor.shape.stack.apply_seq())
    end)


    it("returns ANSI sequence for setting the cursor shape", function()
      cursor.shape.stack.push_seq("block")
      assert.are.equal(cursor.shape.set_seq("block"), cursor.shape.stack.apply_seq())
      cursor.shape.stack.push_seq("underline")
      assert.are.equal(cursor.shape.set_seq("underline"), cursor.shape.stack.apply_seq())
    end)

  end)



  describe("shape.stack.push_seq()", function()

    it("returns ANSI sequence for setting the cursor shape", function()
      assert.are.equal(cursor.shape.set_seq("block"), cursor.shape.stack.push_seq("block"))
      assert.are.equal(cursor.shape.set_seq("underline"), cursor.shape.stack.push_seq("underline"))
    end)


    it("returns a descriptive error on a bad shape", function()
      assert.has.error(function()
        cursor.shape.stack.push_seq(true)
      end, 'Invalid cursor shape: "true". Expected one of: "bar", "bar_blink", "block", "block_blink", "underline", "underline_blink"')
    end)

  end)



  describe("shape.stack.pop_seq()", function()

    it("returns ANSI sequence at the top of the stack", function()
      cursor.shape.stack.push_seq("block")
      cursor.shape.stack.push_seq("underline")
      assert.are.equal(cursor.shape.set_seq("block"), cursor.shape.stack.pop_seq())
    end)


    it("pops multiple items at once", function()
      cursor.shape.stack.push_seq("block")
      cursor.shape.stack.push_seq("underline")
      cursor.shape.stack.push_seq("underline")
      cursor.shape.stack.push_seq("underline")
      cursor.shape.stack.push_seq("underline")
      assert.are.equal(cursor.shape.set_seq("block"), cursor.shape.stack.pop_seq(4))
    end)


    it("over-popping ends with the last item", function()
      cursor.shape.stack.push_seq("block")
      cursor.shape.stack.push_seq("block")
      cursor.shape.stack.push_seq("block")
      cursor.shape.stack.push_seq("block")
      assert.are.equal("\27[0 q", cursor.shape.stack.pop_seq(math.huge))
    end)

  end)



  describe("position.query_seq()", function()

    it("returns ANSI sequence for querying the cursor position", function()
      assert.are.equal("\27[6n", cursor.position.query_seq())
    end)

  end)



  describe("position.get()", function()

    local input
    local old_query
    local query_result -- the 'input.query' mock results to return in a test, will be unpacked, n for value-count

    before_each(function()
      -- Set up mock after modules are reloaded by parent before_each
      input = require("terminal.input")
      old_query = input.query
      query_result = nil

      -- create a mock
      input.query = function(query, pattern)
        assert(query_result, "Test did not set 'query_result' variable")
        assert.are.equal("\27[6n", query)
        assert.are.equal("^\27%[(%d+);(%d+)R$", pattern)
        -- Return the predefined query_result
        return require("pl.utils").unpack(query_result)
      end

      -- Reload cursor.position module to pick up the mocked input.query
      package.loaded["terminal.cursor.position"] = nil
      cursor.position = require("terminal.cursor.position")
    end)


    after_each(function()
      input.query = old_query
    end)


    it("returns the cursor position", function()
      -- mock input.query to return a valid ANSI cursor position response
      query_result = { n = 1, {"12", "34"}}

      local row, col = cursor.position.get()
      assert.are.equal(12, row)
      assert.are.equal(34, col)
    end)


    it("returns nil and error message when query fails", function()
      -- mock input.query to return an error
      query_result = { n = 2, nil, "error reading keyboard: timeout" }

      local row, col = cursor.position.get()
      assert.is_nil(row)
      assert.are.equal("error reading keyboard: timeout", col)
    end)

  end)



  describe("position.set_seq()", function()

    it("returns ANSI sequence for setting the cursor position", function()
      assert.are.equal("\27[5;10H", cursor.position.set_seq(5, 10))
    end)


    it("resolves negative indexes to absolute values", function()
      -- values -5000 shoudl end up being 1
      assert.are.equal("\27[1;1H", cursor.position.set_seq(-5000, -5000))
    end)

  end)



  describe("position.backup_seq()", function()

    it("returns ANSI sequence for backing up the cursor position", function()
      assert.are.equal("\27[s", cursor.position.backup_seq())
    end)

  end)



  describe("position.restore_seq()", function()

    it("returns ANSI sequence for restoring the cursor position", function()
      assert.are.equal("\27[u", cursor.position.restore_seq())
    end)

  end)



  describe("position.up_seq()", function()

    it("returns ANSI sequence for moving the cursor up", function()
      assert.are.equal("\27[5A", cursor.position.up_seq(5))
    end)


    it("defaults to 1 row", function()
      assert.are.equal("\27[1A", cursor.position.up_seq())
    end)


    it("does nothing if 0", function()
      assert.are.equal("", cursor.position.up_seq(0))
    end)

  end)



  describe("position.down_seq()", function()

    it("returns ANSI sequence for moving the cursor down", function()
      assert.are.equal("\27[5B", cursor.position.down_seq(5))
    end)


    it("defaults to 1 row", function()
      assert.are.equal("\27[1B", cursor.position.down_seq())
    end)


    it("does nothing if 0", function()
      assert.are.equal("", cursor.position.down_seq(0))
    end)

  end)



  describe("position.vertical_seq()", function()

    it("returns empty string for zero vertical movement", function()
      assert.are.equal("", cursor.position.vertical_seq(0))
    end)


    it("returns correct sequence for positive vertical movement (down)", function()
      assert.are.equal("\27[3B", cursor.position.vertical_seq(3))
    end)


    it("returns correct sequence for negative vertical movement (up)", function()
      assert.are.equal("\27[2A", cursor.position.vertical_seq(-2))
    end)

  end)



  describe("position.left_seq()", function()

    it("returns ANSI sequence for moving the cursor left", function()
      assert.are.equal("\27[5D", cursor.position.left_seq(5))
    end)


    it("defaults to 1 column", function()
      assert.are.equal("\27[1D", cursor.position.left_seq())
    end)


    it("does nothing if 0", function()
      assert.are.equal("", cursor.position.left_seq(0))
    end)

  end)



  describe("position.right_seq()", function()

    it("returns ANSI sequence for moving the cursor right", function()
      assert.are.equal("\27[5C", cursor.position.right_seq(5))
    end)


    it("defaults to 1 column", function()
      assert.are.equal("\27[1C", cursor.position.right_seq())
    end)


    it("does nothing if 0", function()
      assert.are.equal("", cursor.position.right_seq(0))
    end)

  end)



  describe("position.horizontal_seq()", function()

    it("returns empty string for zero horizontal movement", function()
      assert.are.equal("", cursor.position.horizontal_seq(0))
    end)


    it("returns correct sequence for positive horizontal movement (right)", function()
      assert.are.equal("\27[3C", cursor.position.horizontal_seq(3))
    end)


    it("returns correct sequence for negative horizontal movement (left)", function()
      assert.are.equal("\27[2D", cursor.position.horizontal_seq(-2))
    end)

  end)



  describe("position.move_seq()", function()

    it("returns correct sequence for moving the cursor horizontally and vertically", function()
      assert.are.equal("\27[3B\27[2C", cursor.position.move_seq(3, 2))
    end)


    it("defaults to 0 rows and 0 columns", function()
      assert.are.equal("", cursor.position.move_seq())
    end)


    it("returns correct sequence for moving the cursor horizontally and vertically", function()
      assert.are.equal("\27[3A\27[2D", cursor.position.move_seq(-3, -2))
    end)

  end)



  describe("position.column_seq()", function()

    it("returns correct sequence for moving the cursor to a column on the current row", function()
      assert.are.equal("\27[10G", cursor.position.column_seq(10))
    end)


    pending("negative indices", function()
      -- TODO: implement
    end)

  end)



  describe("position.row_seq()", function()

    it("returns correct sequence for moving the cursor to a row on the current column", function()
      assert.are.equal("\27[5d", cursor.position.row_seq(5))
    end)


    pending("negative indices", function()
      -- TODO: implement
    end)

  end)



  describe("position.stack.push_seq()", function()

    local old_get

    setup(function()
      old_get = cursor.position.get
    end)


    teardown(function()
      cursor.position.get = old_get
    end)


    it("returns ANSI sequence for moving to a new position", function()
      -- mock position.get to return fixed values
      cursor.position.get = function() return 2, 3 end

      local seq = cursor.position.stack.push_seq(5, 10)
      assert.are.equal(cursor.position.set_seq(5, 10), seq)
    end)


    it("returns empty string when no position is provided", function()
      cursor.position.get = function() return 2, 3 end

      assert.are.equal("", cursor.position.stack.push_seq())
    end)

  end)



  describe("position.stack.pop_seq()", function()

    local old_get

    setup(function()
      old_get = cursor.position.get
    end)


    teardown(function()
      cursor.position.get = old_get
    end)


    it("returns ANSI sequence for moving to the previous position", function()
      -- mock position.get to return fixed values

      cursor.position.get = function() return 2, 3 end

      cursor.position.stack.push_seq() -- push current position (2,3)
      cursor.position.get = function() return 5, 10 end
      cursor.position.stack.push_seq() -- push another position (5,10)

      assert.are.equal(cursor.position.set_seq(5, 10), cursor.position.stack.pop_seq())
      assert.are.equal(cursor.position.set_seq(2, 3), cursor.position.stack.pop_seq())
    end)


    it("pops multiple items at once", function()
      -- mock position.get to return different positions
      local positions = { { 1, 1 }, { 2, 2 }, { 3, 3 }, { 4, 4 }, { 5, 5 } }
      local index = 0

      cursor.position.get = function()
        index = index + 1
        return positions[index][1], positions[index][2]
      end

      -- Push multiple positions
      for _ = 1, 5 do
        cursor.position.stack.push_seq()
      end

      -- Pop 3 positions at once, should return sequence for position 2
      assert.are.equal(cursor.position.set_seq(3, 3), cursor.position.stack.pop_seq(3))
    end)


    it("returns empty string when popping from empty stack", function()
      -- Create a clean stack
      for mod in pairs(package.loaded) do
        if mod:match("^terminal") then
          package.loaded[mod] = nil
        end
      end
      cursor = require "terminal.cursor"

      assert.are.equal("", cursor.position.stack.pop_seq())
    end)


    it("over-popping returns empty string", function()
      -- mock position.get to return fixed values
      cursor.position.get = function() return 2, 3 end

      cursor.position.stack.push_seq() -- push position

      -- Pop way more than we pushed
      assert.are.equal(cursor.position.set_seq(2, 3), cursor.position.stack.pop_seq(1)) -- first pop works
      assert.are.equal("", cursor.position.stack.pop_seq(100))                          -- over-popping
    end)

  end)

end)
