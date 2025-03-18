describe("Scroll stack", function()

  local stack, scroll

  before_each(function()
    _G._TEST = true
    stack = require "terminal.scroll.stack"
    scroll = require "terminal.scroll"
  end)


  after_each(function()
    _G._TEST = nil
    for mod in pairs(package.loaded) do
      if mod:match("^terminal") then
        package.loaded[mod] = nil
      end
    end
  end)



  it("has a reset as the first item on the stack", function()
    assert.are.same({ scroll.scroll_resets() }, stack.__scrollstack)
  end)



  describe("pushs()", function()

    it("pushes a new scroll region onto the stack", function()
      local expected = scroll.scroll_regions(5, 10)
      local seq = stack.pushs(5, 10)
      assert.are.same({ scroll.scroll_resets(), expected }, stack.__scrollstack)
      assert.are.equal(expected, seq)
    end)

  end)



  describe("pops()", function()

    it("doesn't pop beyond the last item", function()
      local expected = scroll.scroll_resets()
      local seq = stack.pops(100)
      assert.are.same({ expected }, stack.__scrollstack)
      assert.are.equal(expected, seq)
    end)


    it("can pop 'math.huge' items", function()
      local expected = scroll.scroll_resets()
      local seq = stack.pops(math.huge)
      assert.are.same({ expected }, stack.__scrollstack)
      assert.are.equal(expected, seq)
    end)


    it("pops items in the right order", function()
      local seq1 = stack.pushs(5, 10)
      local seq2 = stack.pushs(15, 20)
      local _    = stack.pushs(25, 30)

      assert.are.equal(seq2, stack.pops(1))
      assert.are.equal(seq1, stack.pops(1))
      assert.are.equal(scroll.scroll_resets(), stack.pops(1))
    end)


    it("pops many items at once", function()
      local seq
      for i = 1, 10 do
        local s = stack.pushs(i, i + 5)
        if i == 10 - 5 then
          seq = s
        end
      end
      local res = stack.pops(5)
      assert.are.equal(seq, res)
    end)


    it("pops many items at once without holes", function()
      for i = 1, 10 do
        stack.pushs(i + 20, i + 25)
      end
      stack.pops(5) -- pops 11, 10, 9, 8, 7
      stack.__scrollstack[1] = nil
      stack.__scrollstack[2] = nil
      stack.__scrollstack[3] = nil
      stack.__scrollstack[4] = nil
      stack.__scrollstack[5] = nil
      stack.__scrollstack[6] = nil
      assert.same({}, stack.__scrollstack)
    end)

  end)



  describe("applys()", function()

    it("returns the current scroll region sequence", function()
      assert.are.equal(scroll.scroll_resets(), stack.applys())
      local seq = stack.pushs(5, 10)
      assert.are.equal(seq, stack.applys())
    end)

  end)

end)
