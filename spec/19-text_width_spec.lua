local helpers = require "spec.helpers"


describe("terminal.text.width", function()

  local width

  setup(function()
    helpers.load()
    width = require("terminal.text.width")
  end)


  teardown(function()
    helpers.unload()
  end)



  describe("utf8cwidth()", function()

    it("returns 1 for ASCII characters", function()
      assert.are.equal(1, width.utf8cwidth(65))
      assert.are.equal(1, width.utf8cwidth("A"))
      assert.are.equal(1, width.utf8cwidth(" "))
    end)


    it("accepts string or codepoint and returns same width", function()
      assert.are.equal(width.utf8cwidth("x"), width.utf8cwidth(0x78))
    end)


    it("returns 2 for fullwidth characters (e.g. CJK)", function()
      assert.are.equal(2, width.utf8cwidth("你"))
      assert.are.equal(2, width.utf8cwidth(0x4F60))
    end)


    it("uses ambiguous_width for ambiguous characters", function()
      local mid = require("utf8").char(0x00B7)
      width.set_ambiguous_width(1)
      assert.are.equal(1, width.utf8cwidth(mid), "ambiguous_width=1 should give 1")
      width.set_ambiguous_width(2)
      local w2 = width.utf8cwidth(mid)
      assert.is_true(w2 == 1 or w2 == 2, "ambiguous_width=2 should give 1 or 2, got " .. tostring(w2))
      width.set_ambiguous_width(1)
    end)


    it("errors on invalid type", function()
      assert.has_error(function()
        width.utf8cwidth({})
      end, "expected string or number, got table")
    end)

  end)



  describe("utf8swidth()", function()

    it("returns 0 for empty string", function()
      assert.are.equal(0, width.utf8swidth(""))
    end)


    it("returns correct width for ASCII string", function()
      assert.are.equal(5, width.utf8swidth("Hello"))
    end)


    it("returns correct width for double-width characters", function()
      assert.are.equal(4, width.utf8swidth("你好"))
    end)


    it("returns correct width for mixed ASCII and wide", function()
      assert.are.equal(6, width.utf8swidth("Hi你好"))
    end)


    it("respects set ambiguous_width", function()
      local mid = require("utf8").char(0x00B7)
      width.set_ambiguous_width(1)
      local w1 = width.utf8swidth(mid)
      width.set_ambiguous_width(2)
      local w2 = width.utf8swidth(mid)
      assert.are.equal(1, w1)
      assert.is_true(w2 == 1 or w2 == 2, "ambiguous_width=2 should give 1 or 2, got " .. tostring(w2))
      width.set_ambiguous_width(1)
    end)

  end)



  describe("set_ambiguous_width()", function()

    it("accepts only 1 or 2", function()
      width.set_ambiguous_width(1)
      width.set_ambiguous_width(2)
      assert.has_error(function()
        width.set_ambiguous_width(0)
      end, "ambiguous_width must be 1 or 2, got 0")
      assert.has_error(function()
        width.set_ambiguous_width(3)
      end, "ambiguous_width must be 1 or 2, got 3")
    end)

  end)



  describe("detect_ambiguous_width()", function()

    it("returns 1 when terminal not ready (no write)", function()
      width.ambiguous_width = nil
      local w = width.detect_ambiguous_width()
      assert.are.equal(1, w)
      assert.are.equal(1, width.ambiguous_width)
    end)


    it("is idempotent when ambiguous_width already set", function()
      width.set_ambiguous_width(2)
      local w = width.detect_ambiguous_width()
      assert.are.equal(2, w)
      width.set_ambiguous_width(1)
    end)

  end)



  describe("test()", function()

    it("returns same value as utf8swidth for given string", function()
      width.set_ambiguous_width(1)
      local str = "hello"
      assert.are.equal(width.utf8swidth(str), width.test(str))
    end)


    it("returns 0 for empty or nil", function()
      assert.are.equal(0, width.test(""))
      assert.are.equal(0, width.test(nil))
    end)

  end)



  describe("test_write()", function()

    it("returns width of written string", function()
      local str = "ab"
      local w = width.test_write(str)
      assert.are.equal(2, w)
    end)


    it("returns 0 for empty or nil", function()
      assert.are.equal(0, width.test_write(""))
      assert.are.equal(0, width.test_write(nil))
    end)

  end)

end)
