local helpers = require "spec.helpers"


describe("terminal.draw", function()

  local line
  local draw

  setup(function()
    helpers.load()
    line = require("terminal.draw.line")
    draw = require("terminal.draw")
  end)


  teardown(function()
    helpers.unload()
  end)



  describe("vertical_seq()", function()

    it("does not generate negative cursor-left movement at lastcolumn", function()
      local result = line.vertical_seq(3, "|", true)
      assert.are.equal("|\27[1B|\27[1B|", result)
    end)


    it("keeps alignment for double-width characters at lastcolumn", function()
      local result = line.vertical_seq(3, "界", true)
      assert.are.equal("界\27[1D\27[1B界\27[1D\27[1B界", result)
    end)


    it("keeps regular cursor-left movement when not at lastcolumn", function()
      local result = line.vertical_seq(3, "|", false)
      assert.are.equal("|\27[1D\27[1B|\27[1D\27[1B|", result)
    end)

  end)



  describe("title_seq()", function()

    it("creates title sequence with empty title", function()
      local result = line.title_seq(10, "")
      assert.are.equal("──────────", result)
    end)


    it("creates title sequence with nil title", function()
      local result = line.title_seq(10, nil)
      assert.are.equal("──────────", result)
    end)


    it("creates title sequence with simple title", function()
      local result = line.title_seq(10, "Test")
      assert.are.equal("───Test───", result)
    end)


    it("creates title sequence with custom character", function()
      local result = line.title_seq(8, "Hi", "=")
      assert.are.equal("===Hi===", result)
    end)


    it("creates title sequence with prefix and postfix", function()
      local result = line.title_seq(12, "Title", "─", "┤ ", " ├")
      assert.are.equal("─┤ Title ├──", result)
    end)


    it("handles exact fit for title", function()
      local result = line.title_seq(4, "Hi")
      assert.are.equal("─Hi─", result)
    end)


    it("handles title that's too long - truncates with ellipsis", function()
      local result = line.title_seq(8, "VeryLongTitle")
      assert.are.equal("VeryLon…", result)
    end)


    it("handles title that's too long with prefix/postfix", function()
      local result = line.title_seq(10, "VeryLongTitle", "─", "┤ ", " ├")
      assert.are.equal("┤ VeryL… ├", result)
    end)


    it("omits title when width too small with prefix/postfix", function()
      local result = line.title_seq(5, "Test", "─", "┤ ", " ├")
      assert.are.equal("─────", result)
    end)


    it("handles zero width", function()
      local result = line.title_seq(0, "Test")
      assert.are.equal("", result)
    end)


    it("handles empty prefix and postfix", function()
      local result = line.title_seq(8, "Test", "─", "", "")
      assert.are.equal("──Test──", result)
    end)


    it("handles single character title", function()
      local result = line.title_seq(5, "A")
      assert.are.equal("──A──", result)
    end)


    it("handles title with spaces", function()
      local result = line.title_seq(10, "Hello World")
      assert.are.equal("Hello Wor…", result) -- Should truncate
    end)


    it("handles double-width unicode characters in title", function()
      local result = line.title_seq(8, "测试")
      assert.are.equal("──测试──", result)
    end)


    it("handles very large width", function()
      local result = line.title_seq(1000, "Test")
      assert.is_string(result)
      -- The result will be longer than 1000 due to the title and padding
      assert.is_true(#result >= 1000)
    end)


    it("handles very long title", function()
      local long_title = string.rep("A", 1000)
      local result = line.title_seq(10, long_title)
      assert.are.equal("AAAAAAAAA…", result)
    end)


    it("handles special characters in title", function()
      local result = line.title_seq(11, "hello 测试!")
      assert.are.equal("hello 测试!", result)

      local result = line.title_seq(10, "hello 测试!")
      assert.are.equal("hello 测…─", result)
    end)


    it("drops the title if too long and 'drop' is specified", function()
      local result = line.title_seq(10, "hello 测试!", nil, nil, nil, "drop")
      assert.are.equal("──────────", result)
    end)


    it("truncates to the left if the title is too long and 'left' is specified", function()
      local result = line.title_seq(10, "hello 测试!", nil, nil, nil, "left")
      assert.are.equal("…llo 测试!", result)
    end)

  end)



  describe("title()", function()

    before_each(function()
      helpers.clear_output()
    end)


    it("has the same parameter order as title_seq(width, title, ...)", function()
      local expected = line.title_seq(10, "Test")
      line.title(10, "Test")
      assert.are.equal(expected, helpers.get_output())
    end)


    it("returns true", function()
      local result = line.title(10, "Test")
      assert.is_true(result)
    end)


    it("writes same output as title_seq for simple title", function()
      local expected = line.title_seq(10, "Test")
      line.title(10, "Test")
      assert.are.equal(expected, helpers.get_output())
    end)


    it("writes same output as title_seq with custom character", function()
      local expected = line.title_seq(8, "Hi", "=")
      line.title(8, "Hi", "=")
      assert.are.equal(expected, helpers.get_output())
    end)


    it("writes same output as title_seq with prefix and postfix", function()
      local expected = line.title_seq(12, "Title", "─", "┤ ", " ├")
      line.title(12, "Title", "─", "┤ ", " ├")
      assert.are.equal(expected, helpers.get_output())
    end)


    it("writes same output as title_seq with nil title", function()
      local expected = line.title_seq(10, nil)
      line.title(10, nil)
      assert.are.equal(expected, helpers.get_output())
    end)

  end)


  describe("box_fmt:copy()", function()

    it("copies all fields from the source format", function()
      local src = draw.box_fmt.single
      local copy = src:copy()
      assert.are.equal(src.t,    copy.t)
      assert.are.equal(src.b,    copy.b)
      assert.are.equal(src.l,    copy.l)
      assert.are.equal(src.r,    copy.r)
      assert.are.equal(src.tl,   copy.tl)
      assert.are.equal(src.tr,   copy.tr)
      assert.are.equal(src.bl,   copy.bl)
      assert.are.equal(src.br,   copy.br)
      assert.are.equal(src.pre,  copy.pre)
      assert.are.equal(src.post, copy.post)
    end)

    it("returns a distinct table", function()
      local copy = draw.box_fmt.single:copy()
      assert.are_not.equal(draw.box_fmt.single, copy)
    end)

    it("modifications to the copy do not affect the source", function()
      local copy = draw.box_fmt.single:copy()
      copy.tl = "X"
      assert.are_not.equal("X", draw.box_fmt.single.tl)
    end)

    it("the copy has a copy method (variations of variations)", function()
      local copy = draw.box_fmt.single:copy()
      assert.is_function(copy.copy)
    end)

    it("copy of a copy carries all fields", function()
      local copy1 = draw.box_fmt.single:copy()
      copy1.tl = "X"
      local copy2 = copy1:copy()
      assert.are.equal("X", copy2.tl)
      assert.are.equal(draw.box_fmt.single.t, copy2.t)
    end)

    it("works on every predefined format", function()
      for _, name in ipairs({ "single", "rounded", "single_top", "double", "double_top" }) do
        local fmt = draw.box_fmt[name]
        local copy = fmt:copy()
        assert.is_function(copy.copy, name .. ":copy() should return a copyable table")
      end
    end)

  end)

end)
