describe("Cursor", function()

  local cursor, old_sys_termsize

  before_each(function()
    for mod in pairs(package.loaded) do
      if mod:match("^terminal") then
        package.loaded[mod] = nil
      end
    end

    local sys = require "system"
    old_sys_termsize = sys.termsize
    if os.getenv("GITHUB_ACTIONS") then
      sys.termsize = function()
        return 25, 80
      end
    end

    cursor = require "terminal.cursor"
  end)


  after_each(function()
    require("system").termsize = old_sys_termsize
  end)




  describe("visible.set()", function()

    it("returns ANSI sequence for hiding the cursor", function()
      assert.are.equal("\27[?25l", cursor.visible.sets(false))
    end)


    it("returns ANSI sequence for showing the cursor", function()
      assert.are.equal("\27[?25h", cursor.visible.sets(true))
    end)


    it("defaults to true", function()
      assert.are.equal(cursor.visible.sets(true), cursor.visible.sets())
    end)

  end)



  describe("visible.stack.applys()", function()

    it("returns ANSI sequence for showing the cursor upon start", function()
      assert.are.equal("\27[?25h", cursor.visible.stack.applys())
    end)


    it("returns ANSI sequence for showing/hiding the cursor", function()
      cursor.visible.stack.pushs(false)
      assert.are.equal("\27[?25l", cursor.visible.stack.applys())
      cursor.visible.stack.pushs(true)
      assert.are.equal("\27[?25h", cursor.visible.stack.applys())
    end)

  end)



  describe("visible.stack.pushs()", function()

    it("returns ANSI sequence for hiding the cursor", function()
      assert.are.equal("\27[?25l", cursor.visible.stack.pushs(false))
    end)


    it("returns ANSI sequence for showing the cursor", function()
      assert.are.equal("\27[?25h", cursor.visible.stack.pushs(true))
    end)

  end)



  describe("visible.stack.pops()", function()

    it("returns ANSI sequence at the top of the stack", function()
      cursor.visible.stack.pushs(false)
      cursor.visible.stack.pushs(true)
      assert.are.equal("\27[?25l", cursor.visible.stack.pops())
      assert.are.equal("\27[?25h", cursor.visible.stack.pops())
    end)


    it("pops multiple items at once", function()
      cursor.visible.stack.pushs(false)
      cursor.visible.stack.pushs(true)
      cursor.visible.stack.pushs(true)
      cursor.visible.stack.pushs(true)
      cursor.visible.stack.pushs(true)
      assert.are.equal("\27[?25l", cursor.visible.stack.pops(4))
    end)


    it("over-popping ends with the last item", function()
      cursor.visible.stack.pushs(false)
      cursor.visible.stack.pushs(false)
      cursor.visible.stack.pushs(false)
      cursor.visible.stack.pushs(false)
      assert.are.equal("\27[?25h", cursor.visible.stack.pops(math.huge))
    end)

  end)



  describe("shape.set()", function()

    it("returns ANSI sequence for setting the cursor shape", function()
      assert.are.equal("\27[2 q", cursor.shape.sets("block"))
      assert.are.equal("\27[1 q", cursor.shape.sets("block_blink"))
      assert.are.equal("\27[4 q", cursor.shape.sets("underline"))
      assert.are.equal("\27[3 q", cursor.shape.sets("underline_blink"))
      assert.are.equal("\27[6 q", cursor.shape.sets("bar"))
      assert.are.equal("\27[5 q", cursor.shape.sets("bar_blink"))
    end)


    it("returns a descriptive error on a bad shape", function()
      assert.has.error(function()
        cursor.shape.sets(true)
      end, 'Invalid cursor shape: "true". Expected one of: "bar", "bar_blink", "block", "block_blink", "underline", "underline_blink"')
    end)

  end)



  describe("shape.stack.applys()", function()

    it("returns ANSI sequence for resetting the cursor shape upon start", function()
      assert.are.equal("\27[0 q", cursor.shape.stack.applys())
    end)


    it("returns ANSI sequence for setting the cursor shape", function()
      cursor.shape.stack.pushs("block")
      assert.are.equal(cursor.shape.sets("block"), cursor.shape.stack.applys())
      cursor.shape.stack.pushs("underline")
      assert.are.equal(cursor.shape.sets("underline"), cursor.shape.stack.applys())
    end)

  end)



  describe("shape.stack.pushs()", function()

    it("returns ANSI sequence for setting the cursor shape", function()
      assert.are.equal(cursor.shape.sets("block"), cursor.shape.stack.pushs("block"))
      assert.are.equal(cursor.shape.sets("underline"), cursor.shape.stack.pushs("underline"))
    end)


    it("returns a descriptive error on a bad shape", function()
      assert.has.error(function()
        cursor.shape.stack.pushs(true)
      end, 'Invalid cursor shape: "true". Expected one of: "bar", "bar_blink", "block", "block_blink", "underline", "underline_blink"')
    end)

  end)



  describe("shape.stack.pops()", function()

    it("returns ANSI sequence at the top of the stack", function()
      cursor.shape.stack.pushs("block")
      cursor.shape.stack.pushs("underline")
      assert.are.equal(cursor.shape.sets("block"), cursor.shape.stack.pops())
    end)


    it("pops multiple items at once", function()
      cursor.shape.stack.pushs("block")
      cursor.shape.stack.pushs("underline")
      cursor.shape.stack.pushs("underline")
      cursor.shape.stack.pushs("underline")
      cursor.shape.stack.pushs("underline")
      assert.are.equal(cursor.shape.sets("block"), cursor.shape.stack.pops(4))
    end)


    it("over-popping ends with the last item", function()
      cursor.shape.stack.pushs("block")
      cursor.shape.stack.pushs("block")
      cursor.shape.stack.pushs("block")
      cursor.shape.stack.pushs("block")
      assert.are.equal("\27[0 q", cursor.shape.stack.pops(math.huge))
    end)

  end)



  describe("position.querys()", function()

    it("returns ANSI sequence for querying the cursor position", function()
      assert.are.equal("\27[6n", cursor.position.querys())
    end)

  end)



  describe("position.get()", function()

    pending("returns the cursor position", function()
      -- TODO: implement
    end)

  end)



  describe("position.sets()", function()

    it("returns ANSI sequence for setting the cursor position", function()
      assert.are.equal("\27[5;10H", cursor.position.sets(5, 10))
    end)


    it("resolves negative indexes to absolute values", function()
      -- values -5000 shoudl end up being 1
      assert.are.equal("\27[1;1H", cursor.position.sets(-5000, -5000))
    end)

  end)



  describe("position.backups()", function()

    it("returns ANSI sequence for backing up the cursor position", function()
      assert.are.equal("\27[s", cursor.position.backups())
    end)

  end)



  describe("position.restores()", function()

    it("returns ANSI sequence for restoring the cursor position", function()
      assert.are.equal("\27[u", cursor.position.restores())
    end)

  end)



  describe("position.ups()", function()

    it("returns ANSI sequence for moving the cursor up", function()
      assert.are.equal("\27[5A", cursor.position.ups(5))
    end)


    it("defaults to 1 row", function()
      assert.are.equal("\27[1A", cursor.position.ups())
    end)

  end)



  describe("position.downs()", function()

    it("returns ANSI sequence for moving the cursor down", function()
      assert.are.equal("\27[5B", cursor.position.downs(5))
    end)


    it("defaults to 1 row", function()
      assert.are.equal("\27[1B", cursor.position.downs())
    end)

  end)



  describe("position.verticals()", function()

    it("returns empty string for zero vertical movement", function()
      assert.are.equal("", cursor.position.verticals(0))
    end)


    it("returns correct sequence for positive vertical movement (down)", function()
      assert.are.equal("\27[3B", cursor.position.verticals(3))
    end)


    it("returns correct sequence for negative vertical movement (up)", function()
      assert.are.equal("\27[2A", cursor.position.verticals(-2))
    end)

  end)



  describe("position.lefts()", function()

    it("returns ANSI sequence for moving the cursor left", function()
      assert.are.equal("\27[5D", cursor.position.lefts(5))
    end)


    it("defaults to 1 column", function()
      assert.are.equal("\27[1D", cursor.position.lefts())
    end)

  end)



  describe("position.rights()", function()

    it("returns ANSI sequence for moving the cursor right", function()
      assert.are.equal("\27[5C", cursor.position.rights(5))
    end)


    it("defaults to 1 column", function()
      assert.are.equal("\27[1C", cursor.position.rights())
    end)

  end)



  describe("position.horizontals()", function()

    it("returns empty string for zero horizontal movement", function()
      assert.are.equal("", cursor.position.horizontals(0))
    end)


    it("returns correct sequence for positive horizontal movement (right)", function()
      assert.are.equal("\27[3C", cursor.position.horizontals(3))
    end)


    it("returns correct sequence for negative horizontal movement (left)", function()
      assert.are.equal("\27[2D", cursor.position.horizontals(-2))
    end)

  end)



  describe("position.moves()", function()

    it("returns correct sequence for moving the cursor horizontally and vertically", function()
      assert.are.equal("\27[3B\27[2C", cursor.position.moves(3, 2))
    end)


    it("defaults to 0 rows and 0 columns", function()
      assert.are.equal("", cursor.position.moves())
    end)


    it("returns correct sequence for moving the cursor horizontally and vertically", function()
      assert.are.equal("\27[3A\27[2D", cursor.position.moves(-3, -2))
    end)

  end)



  describe("position.columns()", function()

    it("returns correct sequence for moving the cursor to a column on the current row", function()
      assert.are.equal("\27[10G", cursor.position.columns(10))
    end)


    pending("negative indices", function()
      -- TODO: implement
    end)

  end)



  describe("position.rows()", function()

    it("returns correct sequence for moving the cursor to a row on the current column", function()
      assert.are.equal("\27[5d", cursor.position.rows(5))
    end)


    pending("negative indices", function()
      -- TODO: implement
    end)

  end)

end)
