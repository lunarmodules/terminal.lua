describe("Utf8editLine:", function()

  local Utf8edit

  before_each(function()
    Utf8edit = require("terminal.text.Utf8edit")
  end)


  after_each(function()
    Utf8edit = nil
  end)



  describe("init()", function()

    it("defaults to an empty string", function()
      local line = Utf8edit()
      assert.are.equal("", tostring(line))
    end)


    it("initializes with a given string", function()
      local line = Utf8edit("hello")
      assert.are.equal("hello", tostring(line))
    end)


    it("initializes with an empty string", function()
      local line = Utf8edit("")
      assert.are.equal("", tostring(line))
    end)


    it("initializes with a UTF-8 string", function()
      local line = Utf8edit("こんにちは")
      assert.are.equal("こんにちは", tostring(line))
    end)


    it("initializes cursor position at the end", function()
      local line = Utf8edit("hello")
      assert.are.equal(6, line:pos_char())  -- cursor should be at the end of "hello"
      line:add("!")
      assert.are.equal("hello!", tostring(line))
    end)

  end)



  describe("pos_char()", function()

    it("returns the UTF-8 character index at the current cursor (ASCII)", function()
      local line = Utf8edit("hello")
      assert.are.equal(6, line:pos_char())
      line:left(3)
      assert.are.equal(3, line:pos_char())
    end)


    it("returns the UTF-8 character index at the current cursor (UTF-8)", function()
      local line = Utf8edit("你好吗")
      -- Cursor starts at end (after '吗'), move to position 3 (after '好')
      line:left(1)
      -- Should be at pos 3 (after '好')
      assert.are.equal(3, line:pos_char())
    end)


    it("returns 1 if cursor is at the start of the line", function()
      local line = Utf8edit("hello")
      line:left(5)
      assert.are.equal(1, line:pos_char())
    end)


    it("returns the correct index after edits (UTF-8)", function()
      local line = Utf8edit("你好世界")
      line:left(2) -- move to after '好'
      assert.are.equal(3, line:pos_char())
      line:add("！")
      -- Cursor is after '！', which is character 3
      assert.are.equal(4, line:pos_char())
    end)


    it("returns the correct index at the end of the line", function()
      local line = Utf8edit("hello")
      -- Cursor at end (after 'o')
      assert.are.equal(6, line:pos_char())
    end)


    it("returns the correct index at the end of the line (UTF-8)", function()
      local line = Utf8edit("你好世界")
      -- Cursor at end (after '界')
      assert.are.equal(5, line:pos_char())
    end)

  end)



  describe("pos_col()", function()

    it("returns the column index at the current cursor (ASCII)", function()
      local line = Utf8edit("hello")
      -- Cursor starts at end (after 'o')
      assert.are.equal(6, line:pos_col())
      line:left(3)
      -- Should be at column 3 (after 'l')
      assert.are.equal(3, line:pos_col())
    end)


    it("returns the column index at the current cursor (UTF-8, wide chars)", function()
      local line = Utf8edit("你好吗")
      -- Each Chinese character is typically width 2
      -- Cursor starts at end (after '吗'), so column should be 7
      assert.are.equal(7, line:pos_col())
      line:left(1)
      -- After moving left by 1 char (after '好'), column should be 5
      assert.are.equal(5, line:pos_col())
    end)


    it("returns 1 if cursor is at the start of the line", function()
      local line = Utf8edit("hello")
      line:left(5)
      assert.are.equal(1, line:pos_col())
    end)


    it("returns the correct column after edits (UTF-8, mixed width)", function()
      local line = Utf8edit("你好世界")
      line:left(2) -- move to after '好'
      assert.are.equal(5, line:pos_col())
      line:add("a") -- ASCII, width 1
      -- Cursor is after 'a', which should be column 6
      assert.are.equal(6, line:pos_col())
      line:add("界") -- wide char, width 2
      -- Cursor is after '界', which should be column 8
      assert.are.equal(8, line:pos_col())
    end)


    it("returns the correct column at the end of the line (ASCII)", function()
      local line = Utf8edit("hello")
      assert.are.equal(6, line:pos_col())
    end)


    it("returns the correct column at the end of the line (UTF-8)", function()
      local line = Utf8edit("你好世界")
      -- Each char width 2, so 4*2=8, plus 1 for 1-based index
      assert.are.equal(9, line:pos_col())
    end)

  end)



  describe("len_char()", function()

    it("returns the length in UTF-8 characters for ASCII", function()
      local line = Utf8edit("hello")
      assert.are.equal(5, line:len_char())
    end)


    it("returns the length in UTF-8 characters for multibyte string", function()
      local line = Utf8edit("你好世界")
      assert.are.equal(4, line:len_char())
    end)


    it("returns 0 for an empty string", function()
      local line = Utf8edit("")
      assert.are.equal(0, line:len_char())
    end)


    it("returns correct length after adding characters", function()
      local line = Utf8edit("hi")
      line:add("!")
      assert.are.equal(3, line:len_char())
      line:add("界")
      assert.are.equal(4, line:len_char())
    end)

  end)



  describe("len_col()", function()

    it("returns the column width for ASCII", function()
      local line = Utf8edit("hello")
      assert.are.equal(5, line:len_col())
    end)


    it("returns the column width for wide UTF-8 characters", function()
      local line = Utf8edit("你好世界")
      -- Each Chinese character is width 2, so 4*2 = 8
      assert.are.equal(8, line:len_col())
    end)


    it("returns 0 for an empty string", function()
      local line = Utf8edit("")
      assert.are.equal(0, line:len_col())
    end)


    it("returns correct width after adding mixed-width characters", function()
      local line = Utf8edit("hi")
      line:add("界") -- width 2
      assert.are.equal(4, line:len_col()) -- "hi" (2) + "界" (2)
      line:add("a") -- width 1
      assert.are.equal(5, line:len_col())
    end)

  end)



  describe("add()", function()

    it("adds a character to the line", function()
      local line = Utf8edit("he")
      line:add("l")
      assert.are.equal("hel", tostring(line))
    end)


    it("adds a UTF-8 character to the line", function()
      local line = Utf8edit("你")
      line:add("好")
      assert.are.equal("你好", tostring(line))
    end)


    it("adds a character at the start", function()
      local line = Utf8edit("ello")
      line:left(4)
      line:add("h")
      assert.are.equal("hello", tostring(line))
    end)

  end)



  describe("left()", function()

    it("moves the cursor left by one position", function()
      local line = Utf8edit("hello")
      line:left()
      assert.are.equal(5, line:pos_char())  -- cursor should be at 'o'
      line:add("!")
      assert.are.equal("hell!o", tostring(line))
    end)


    it("moves the cursor left by multiple positions", function()
      local line = Utf8edit("hello")
      line:left(3)
      assert.are.equal(3, line:pos_char())  -- cursor should be at 'o'
      line:add("!")
      assert.are.equal("he!llo", tostring(line))
    end)


    it("does not move left beyond the start of the line", function()
      local line = Utf8edit("hello")
      line:left(10)  -- trying to move left more than available
      assert.are.equal(1, line:pos_char())  -- cursor should be at the start
      line:add("!")
      assert.are.equal("!hello", tostring(line))
    end)


    it("moves the cursor left by one position with UTF-8", function()
      local line = Utf8edit("你好世界")
      assert.are.equal(9, line:pos_col())  -- cursor should be at last column
      assert.are.equal(5, line:pos_char())  -- cursor should be at last character
      line:left()
      assert.are.equal(7, line:pos_col())  -- cursor should be at last character
      assert.are.equal(4, line:pos_char())  -- cursor should be at last character
      line:add("！")
      assert.are.equal("你好世！界", tostring(line))
    end)


    it("moves the cursor left by multiple positions with UTF-8", function()
      local line = Utf8edit("你好世界")
      line:left(3)
      assert.are.equal(2, line:pos_char())  -- cursor should be at third character
      assert.are.equal(3, line:pos_col())  -- cursor should be at third character
      line:add("！")
      assert.are.equal("你！好世界", tostring(line))
    end)


    it("does not move left beyond the start of the line with UTF-8", function()
      local line = Utf8edit("你好世界")
      line:left(10)  -- trying to move left more than available
      assert.are.equal(1, line:pos_char())  -- cursor should be at the start
      line:add("！")
      assert.are.equal("！你好世界", tostring(line))
    end)

  end)



  describe("right()", function()

    it("moves the cursor right by one position", function()
      local line = Utf8edit("hello")
      line:left(3) -- move to position 3
      line:right()
      assert.are.equal(4, line:pos_char())  -- cursor should be at position 4
      line:add("!")
      assert.are.equal("hel!lo", tostring(line))
    end)

    it("moves the cursor right by multiple positions", function()
      local line = Utf8edit("hello")
      line:left(4) -- move to position 2
      line:right(3)
      assert.are.equal(5, line:pos_char())  -- cursor should be at position 5
      line:add("!")
      assert.are.equal("hell!o", tostring(line))
    end)

    it("does not move right beyond the end of the line", function()
      local line = Utf8edit("hello")
      line:right(10)  -- trying to move right more than available
      assert.are.equal(6, line:pos_char())  -- cursor should be at the end
      line:add("!")
      assert.are.equal("hello!", tostring(line))
    end)

  end)



  describe("complex string edits", function()

    it("handles left and right cursor movements with UTF-8", function()
      local line = Utf8edit("你好世界")
      line:left(2)
      line:add("！")
      assert.are.equal(7, line:pos_col())
      assert.are.equal(4, line:pos_char())
      assert.are.equal("你好！世界", tostring(line))
    end)


    it("handles backspace correctly", function()
      local line = Utf8edit("hello")
      line:left()
      line:left()
      line:backspace()
      assert.are.equal(3, line:pos_char())
      assert.are.equal("helo", tostring(line))
    end)


    it("handles backspace correctly with UTF-8", function()
      local line = Utf8edit("你好世界")
      line:left(2)
      line:backspace()
      assert.are.equal(2, line:pos_char())
      assert.are.equal(3, line:pos_col())
      assert.are.equal("你世界", tostring(line))
    end)


    it("handles delete correctly", function()
      local line = Utf8edit("hello")
      line:left(2)
      line:delete()
      assert.are.equal(4, line:pos_char())
      assert.are.equal("helo", tostring(line))
    end)


    it("handles delete correctly with UTF-8", function()
      local line = Utf8edit("你好世界")
      line:left(2)
      line:delete()
      assert.are.equal("你好界", tostring(line))
      assert.are.equal(3, line:pos_char())
      assert.are.equal(5, line:pos_col())
    end)


    it("handles a sequence of edits", function()
      local line = Utf8edit("hello")
      line:left(2)
      line:backspace()
      line:add("y")
      line:right()
      line:add("!")
      assert.are.equal(6, line:pos_char())
      assert.are.equal("heyl!o", tostring(line))
    end)


    it("handles a sequence of edits with UTF-8", function()
      local line = Utf8edit("你好世界")
      line:left(2)
      line:backspace()
      line:add("a")
      line:right()
      line:add("！")
      assert.are.equal(8, line:pos_col())
      assert.are.equal(5, line:pos_char())
      assert.are.equal("你a世！界", tostring(line))
    end)


    it("handles spamming of keys", function()
      local line = Utf8edit("你好世界")
      line:left(10)
      line:backspace(3)
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
      line:right(13)
      line:delete(3)
      assert.are.equal(5, line:pos_char())
      assert.are.equal(9, line:pos_col())
      assert.are.equal("你好世界", tostring(line))
    end)

  end)

end)
