local helpers = require "spec.helpers"


describe("Scroll stack", function()

  local terminal, stack, scroll

  before_each(function()
    terminal = helpers.load()
    stack = terminal.scroll.stack
    scroll = terminal.scroll
  end)


  after_each(function()
    helpers.unload()
  end)



  it("has entire screen as the first item on the stack", function()
    assert.are.same({ {1, -1} }, stack.__scrollstack)
  end)



  describe("pushs_seq()", function()

    it("pushes a new scroll region onto the stack", function()
      local expected = scroll.set_seq(5, 10)
      local seq = stack.push_seq(5, 10)
      assert.are.same({ { 1, -1 }, { 5, 10 } }, stack.__scrollstack)
      assert.are.equal(expected, seq)
    end)


    it("pushes a scroll region with negative indexes onto the stack", function()
      local expected = scroll.set_seq(-5, -1)
      local seq = stack.push_seq(-5, -1)
      assert.are.same({ { 1, -1 }, { -5, -1 } }, stack.__scrollstack)
      assert.are.equal(expected, seq)
    end)

  end)



  describe("pop_seq()", function()

    it("doesn't pop beyond the last item", function()
      local expected = scroll.set_seq(1, -1)
      local seq = stack.pop_seq(100)
      assert.are.same({ { 1, -1 } }, stack.__scrollstack)
      assert.are.equal(expected, seq)
    end)


    it("can pop 'math.huge' items", function()
      local expected = scroll.set_seq(1, -1)
      local seq = stack.pop_seq(math.huge)
      assert.are.same({ { 1, -1 } }, stack.__scrollstack)
      assert.are.equal(expected, seq)
    end)


    it("pops items in the right order", function()
      local seq1 = stack.push_seq(5, 10)
      local seq2 = stack.push_seq(15, 20)
      local _    = stack.push_seq(25, 30)

      assert.are.equal(seq2, stack.pop_seq(1))
      assert.are.equal(seq1, stack.pop_seq(1))
      assert.are.equal(scroll.set_seq(1, -1), stack.pop_seq(1))
    end)


    it("pops many items at once", function()
      local seq
      for i = 1, 10 do
        local s = stack.push_seq(i, i + 5)
        if i == 10 - 5 then
          seq = s
        end
      end
      local res = stack.pop_seq(5)
      assert.are.equal(seq, res)
    end)


    it("pops many items at once without holes", function()
      for i = 1, 10 do
        stack.push_seq(i + 20, i + 25)
      end
      stack.pop_seq(5) -- pops 11, 10, 9, 8, 7
      stack.__scrollstack[1] = nil
      stack.__scrollstack[2] = nil
      stack.__scrollstack[3] = nil
      stack.__scrollstack[4] = nil
      stack.__scrollstack[5] = nil
      stack.__scrollstack[6] = nil
      assert.same({}, stack.__scrollstack)
    end)

  end)



  describe("apply_seq()", function()

    it("returns the current scroll region sequence", function()
      assert.are.equal(scroll.set_seq(1,-1), stack.apply_seq())
      local seq = stack.push_seq(5, 10)
      assert.are.equal(seq, stack.apply_seq())
    end)

  end)

end)
