describe("Cursor", function()

  local cursor

  before_each(function()
    for mod in pairs(package.loaded) do
      if mod:match("^terminal") then
        package.loaded[mod] = nil
      end
    end

    cursor = require "terminal.cursor"
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



  describe("visible.stack.apply()", function()

    it("returns ANSI sequence for showing the cursor upon start", function()
      assert.are.equal("\27[?25h", cursor.visible.stack.applys())
    end)


    it("returns ANSI sequence for showing/hiding the cursor", function()
      cursor.visible.stack.push(false)
      assert.are.equal("\27[?25l", cursor.visible.stack.applys())
      cursor.visible.stack.push(true)
      assert.are.equal("\27[?25h", cursor.visible.stack.applys())
    end)

  end)



  describe("visible.stack.push()", function()

    it("returns ANSI sequence for hiding the cursor", function()
      assert.are.equal("\27[?25l", cursor.visible.stack.pushs(false))
    end)


    it("returns ANSI sequence for showing the cursor", function()
      assert.are.equal("\27[?25h", cursor.visible.stack.pushs(true))
    end)

  end)



  describe("visible.stack.pop()", function()

    it("returns ANSI sequence at the top of the stack", function()
      cursor.visible.stack.push(false)
      cursor.visible.stack.push(true)
      assert.are.equal("\27[?25l", cursor.visible.stack.pops())
      assert.are.equal("\27[?25h", cursor.visible.stack.pops())
    end)


    it("pops multiple items at once", function()
      cursor.visible.stack.push(false)
      cursor.visible.stack.push(true)
      cursor.visible.stack.push(true)
      cursor.visible.stack.push(true)
      cursor.visible.stack.push(true)
      assert.are.equal("\27[?25l", cursor.visible.stack.pops(4))
    end)


    it("over-popping ends with the last item", function()
      cursor.visible.stack.push(false)
      cursor.visible.stack.push(false)
      cursor.visible.stack.push(false)
      cursor.visible.stack.push(false)
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



  describe("shape.stack.apply()", function()

    it("returns ANSI sequence for resetting the cursor shape upon start", function()
      assert.are.equal("\27[0 q", cursor.shape.stack.applys())
    end)


    it("returns ANSI sequence for setting the cursor shape", function()
      cursor.shape.stack.push("block")
      assert.are.equal(cursor.shape.sets("block"), cursor.shape.stack.applys())
      cursor.shape.stack.push("underline")
      assert.are.equal(cursor.shape.sets("underline"), cursor.shape.stack.applys())
    end)

  end)



  describe("shape.stack.push()", function()

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



  describe("shape.stack.pop()", function()

    it("returns ANSI sequence at the top of the stack", function()
      cursor.shape.stack.push("block")
      cursor.shape.stack.push("underline")
      assert.are.equal(cursor.shape.sets("block"), cursor.shape.stack.pops())
    end)


    it("pops multiple items at once", function()
      cursor.shape.stack.push("block")
      cursor.shape.stack.push("underline")
      cursor.shape.stack.push("underline")
      cursor.shape.stack.push("underline")
      cursor.shape.stack.push("underline")
      assert.are.equal(cursor.shape.sets("block"), cursor.shape.stack.pops(4))
    end)


    it("over-popping ends with the last item", function()
      cursor.shape.stack.push("block")
      cursor.shape.stack.push("block")
      cursor.shape.stack.push("block")
      cursor.shape.stack.push("block")
      assert.are.equal("\27[0 q", cursor.shape.stack.pops(math.huge))
    end)

  end)

end)
