describe("Scroll stack", function()

  local stack, scroll, old_sys_termsize

  before_each(function()
    _G._TEST = true

    local sys = require "system"
    old_sys_termsize = sys.termsize
    if os.getenv("GITHUB_ACTIONS") then
      sys.termsize = function()
        return 25, 80
      end
    end

    stack = require "terminal.scroll.stack"
    scroll = require "terminal.scroll"
  end)


  after_each(function()
    _G._TEST = nil

    require("system").termsize = old_sys_termsize

    for mod in pairs(package.loaded) do
      if mod:match("^terminal") then
        package.loaded[mod] = nil
      end
    end
  end)



  it("has entire screen as the first item on the stack", function()
    assert.are.same({ {1, -1} }, stack.__scrollstack)
  end)



  describe("pushs()", function()

    it("pushes a new scroll region onto the stack", function()
      local expected = scroll.sets(5, 10)
      local seq = stack.pushs(5, 10)
      assert.are.same({ { 1, -1 }, { 5, 10 } }, stack.__scrollstack)
      assert.are.equal(expected, seq)
    end)


    it("pushes a scroll region with negative indexes onto the stack", function()
      local expected = scroll.sets(-5, -1)
      local seq = stack.pushs(-5, -1)
      assert.are.same({ { 1, -1 }, { -5, -1 } }, stack.__scrollstack)
      assert.are.equal(expected, seq)
    end)

  end)



  describe("pops()", function()

    it("doesn't pop beyond the last item", function()
      local expected = scroll.sets(1, -1)
      local seq = stack.pops(100)
      assert.are.same({ { 1, -1 } }, stack.__scrollstack)
      assert.are.equal(expected, seq)
    end)


    it("can pop 'math.huge' items", function()
      local expected = scroll.sets(1, -1)
      local seq = stack.pops(math.huge)
      assert.are.same({ { 1, -1 } }, stack.__scrollstack)
      assert.are.equal(expected, seq)
    end)


    it("pops items in the right order", function()
      local seq1 = stack.pushs(5, 10)
      local seq2 = stack.pushs(15, 20)
      local _    = stack.pushs(25, 30)

      assert.are.equal(seq2, stack.pops(1))
      assert.are.equal(seq1, stack.pops(1))
      assert.are.equal(scroll.sets(1, -1), stack.pops(1))
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
      assert.are.equal(scroll.sets(1,-1), stack.applys())
      local seq = stack.pushs(5, 10)
      assert.are.equal(seq, stack.applys())
    end)

  end)

end)
