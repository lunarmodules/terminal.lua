describe("Utf8editLine:", function()

  local Utf8edit

  before_each(function()
    Utf8edit = require("terminal.utf8edit")
  end)


  after_each(function()
    Utf8edit = nil
  end)



  describe("init()", function()

    it("defaults to an empty string", function()
      local line = Utf8edit()
      assert.are.equal("", tostring(line))
    end)


    it("defaults to an empty string with an empty table", function()
      local line = Utf8edit {}
      assert.are.equal("", tostring(line))
    end)


    it("defaults to an empty string with an irrelevant table", function()
      local line = Utf8edit { is_lua_terminal_cool = true }
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

    it("initializes with a given table (ASCII)", function()
      local line = Utf8edit({
        value = "hello",
        position = 3,
        word_delimiters = [[abcd]]
      })
      assert.are.equal("hello", tostring(line))
      assert.are.equal(3, line:pos_char())
      assert.are.equal(3, line:pos_col())
      assert.are.same({
        a = true,
        b = true,
        c = true,
        d = true,
      }, line.word_delimiters)
    end)


    it("initializes with a given table (UTF8)", function()
      local line = Utf8edit({
        value = "こんにちは",
        position = 3,
        word_delimiters = [[abcd]]
      })
      assert.are.equal("こんにちは", tostring(line))
      assert.are.equal(3, line:pos_char())
      assert.are.equal(5, line:pos_col())
      assert.are.same({
        a = true,
        b = true,
        c = true,
        d = true,
      }, line.word_delimiters)
    end)

    it("initializes cursor position at the end", function()
      local line = Utf8edit("hello")
      assert.are.equal(6, line:pos_char())  -- cursor should be at the end of "hello"
      line:insert("!")
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
      line:insert("！")
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
      line:insert("a") -- ASCII, width 1
      -- Cursor is after 'a', which should be column 6
      assert.are.equal(6, line:pos_col())
      line:insert("界") -- wide char, width 2
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
      line:insert("!")
      assert.are.equal(3, line:len_char())
      line:insert("界")
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
      line:insert("界") -- width 2
      assert.are.equal(4, line:len_col()) -- "hi" (2) + "界" (2)
      line:insert("a") -- width 1
      assert.are.equal(5, line:len_col())
    end)

  end)



  describe("add()", function()

    it("adds a character to the line", function()
      local line = Utf8edit("he")
      line:insert("l")
      assert.are.equal("hel", tostring(line))
    end)


    it("adds a UTF-8 character to the line", function()
      local line = Utf8edit("你")
      line:insert("好")
      assert.are.equal("你好", tostring(line))
    end)


    it("adds a character at the start", function()
      local line = Utf8edit("ello")
      line:left(4)
      line:insert("h")
      assert.are.equal("hello", tostring(line))
    end)

  end)



  describe("left()", function()

    it("moves the cursor left by one position", function()
      local line = Utf8edit("hello")
      line:left()
      assert.are.equal(5, line:pos_char())  -- cursor should be at 'o'
      line:insert("!")
      assert.are.equal("hell!o", tostring(line))
    end)


    it("moves the cursor left by multiple positions", function()
      local line = Utf8edit("hello")
      line:left(3)
      assert.are.equal(3, line:pos_char())  -- cursor should be at 'o'
      line:insert("!")
      assert.are.equal("he!llo", tostring(line))
    end)


    it("does not move left beyond the start of the line", function()
      local line = Utf8edit("hello")
      line:left(10)  -- trying to move left more than available
      assert.are.equal(1, line:pos_char())  -- cursor should be at the start
      line:insert("!")
      assert.are.equal("!hello", tostring(line))
    end)


    it("moves the cursor left by one position with UTF-8", function()
      local line = Utf8edit("你好世界")
      assert.are.equal(9, line:pos_col())  -- cursor should be at last column
      assert.are.equal(5, line:pos_char())  -- cursor should be at last character
      line:left()
      assert.are.equal(7, line:pos_col())  -- cursor should be at last character
      assert.are.equal(4, line:pos_char())  -- cursor should be at last character
      line:insert("！")
      assert.are.equal("你好世！界", tostring(line))
    end)


    it("moves the cursor left by multiple positions with UTF-8", function()
      local line = Utf8edit("你好世界")
      line:left(3)
      assert.are.equal(2, line:pos_char())  -- cursor should be at third character
      assert.are.equal(3, line:pos_col())  -- cursor should be at third character
      line:insert("！")
      assert.are.equal("你！好世界", tostring(line))
    end)


    it("does not move left beyond the start of the line with UTF-8", function()
      local line = Utf8edit("你好世界")
      line:left(10)  -- trying to move left more than available
      assert.are.equal(1, line:pos_char())  -- cursor should be at the start
      line:insert("！")
      assert.are.equal("！你好世界", tostring(line))
    end)

  end)



  describe("right()", function()

    it("moves the cursor right by one position", function()
      local line = Utf8edit("hello")
      line:left(3) -- move to position 3
      line:right()
      assert.are.equal(4, line:pos_char())  -- cursor should be at position 4
      line:insert("!")
      assert.are.equal("hel!lo", tostring(line))
    end)


    it("moves the cursor right by multiple positions", function()
      local line = Utf8edit("hello")
      line:left(4) -- move to position 2
      line:right(3)
      assert.are.equal(5, line:pos_char())  -- cursor should be at position 5
      line:insert("!")
      assert.are.equal("hell!o", tostring(line))
    end)


    it("does not move right beyond the end of the line", function()
      local line = Utf8edit("hello")
      line:right(10)  -- trying to move right more than available
      assert.are.equal(6, line:pos_char())  -- cursor should be at the end
      line:insert("!")
      assert.are.equal("hello!", tostring(line))
    end)

  end)



  describe("backspace()", function()

    it("removes the character at the end (ASCII)", function()
      local line = Utf8edit("hello")
      line:backspace()
      assert.are.equal("hell", tostring(line))
      assert.are.equal(5, line:pos_char())
    end)


    it("removes the character at the end (UTF-8)", function()
      local line = Utf8edit("你好世界")
      line:backspace()
      assert.are.equal("你好世", tostring(line))
      assert.are.equal(4, line:pos_char())
    end)


    it("does nothing if the cursor is at the start", function()
      local line = Utf8edit("hello")
      line:left(5):backspace()
      assert.are.equal("hello", tostring(line))
      assert.are.equal(1, line:pos_char())
    end)


    it("removes multiple characters if given a count", function()
      local line = Utf8edit("hello")
      line:left():backspace(2)
      assert.are.equal("heo", tostring(line))
      assert.are.equal(3, line:pos_char())
    end)


    it("removes multiple UTF-8 characters if given a count", function()
      local line = Utf8edit("你好世界")
      line:left():backspace(2)
      assert.are.equal("你界", tostring(line))
      assert.are.equal(2, line:pos_char())
    end)


    it("does nothing if the string is empty", function()
      local line = Utf8edit("")
      line:backspace()
      assert.are.equal("", tostring(line))
      assert.are.equal(1, line:pos_char())
    end)

  end)



  describe("delete()", function()

    it("removes the character at the cursor (ASCII)", function()
      local line = Utf8edit("hello")
      line:left(2):delete()
      assert.are.equal("helo", tostring(line))
      assert.are.equal(4, line:pos_char())
    end)


    it("removes the character at the cursor (UTF-8)", function()
      local line = Utf8edit("你好世界")
      line:left(2):delete()
      assert.are.equal("你好界", tostring(line))
      assert.are.equal(3, line:pos_char())
    end)


    it("does nothing if the cursor is at the end", function()
      local line = Utf8edit("hello")
      -- Cursor at end
      line:delete()
      assert.are.equal("hello", tostring(line))
      assert.are.equal(6, line:pos_char())
    end)


    it("removes multiple characters if given a count", function()
      local line = Utf8edit("hello")
      line:left(3):delete(2)
      assert.are.equal("heo", tostring(line))
      assert.are.equal(3, line:pos_char())
    end)


    it("removes multiple UTF-8 characters if given a count", function()
      local line = Utf8edit("你好世界")
      line:left(3):delete(2)
      assert.are.equal("你界", tostring(line))
      assert.are.equal(2, line:pos_char())
    end)


    it("does nothing if the string is empty", function()
      local line = Utf8edit("")
      line:delete()
      assert.are.equal("", tostring(line))
      assert.are.equal(1, line:pos_char())
    end)

  end)



  describe("goto_home()", function()

    it("moves the cursor to the start of the line (ASCII)", function()
      local line = Utf8edit("hello")
      line:goto_home()
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)


    it("moves the cursor to the start of the line (UTF-8)", function()
      local line = Utf8edit("你好世界")
      line:goto_home()
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)


    it("allows inserting at the start after goto_home", function()
      local line = Utf8edit("world")
      line:goto_home():insert("hello ")
      assert.are.equal("hello world", tostring(line))
      assert.are.equal(7, line:pos_char())
      assert.are.equal(7, line:pos_col())
    end)


    it("allows inserting at the start of empty string after goto_home", function()
      local line = Utf8edit("")
      line:goto_home():insert("X")
      assert.are.equal("X", tostring(line))
      assert.are.equal(2, line:pos_char())
      assert.are.equal(2, line:pos_col())
    end)

  end)



  describe("goto_end()", function()

    it("moves the cursor to the end of the line (ASCII)", function()
      local line = Utf8edit("hello")
      line:left(3):goto_end():insert("X")
      assert.are.equal("helloX", tostring(line))
      assert.are.equal(7, line:pos_char())
      assert.are.equal(7, line:pos_col())
    end)


    it("moves the cursor to the end of the line (UTF-8)", function()
      local line = Utf8edit("你好世界")
      line:left(3):goto_end()
      assert.are.equal(5, line:pos_char())
      assert.are.equal(9, line:pos_col())
    end)


    it("allows inserting at the end after goto_end", function()
      local line = Utf8edit("hello")
      line:left(3):goto_end():insert(" world")
      assert.are.equal("hello world", tostring(line))
      assert.are.equal(12, line:pos_char())
      assert.are.equal(12, line:pos_col())
    end)


    it("allows inserting at the end of empty string after goto_end", function()
      local line = Utf8edit("")
      line:goto_end():insert("X")
      assert.are.equal("X", tostring(line))
      assert.are.equal(2, line:pos_char())
      assert.are.equal(2, line:pos_col())
    end)

  end)



  describe("goto_index()", function()

    it("moves the cursor to the given index (ASCII)", function()
      local line = Utf8edit("hello")
      line:goto_index(3):insert("X")
      assert.are.equal("heXllo", tostring(line))
      assert.are.equal(4, line:pos_char())
      assert.are.equal(4, line:pos_col())
    end)


    it("moves the cursor to the given index (UTF-8)", function()
      local line = Utf8edit("1你好世界")
      line:goto_index(3):insert("X")
      assert.are.equal("1你X好世界", tostring(line))
      assert.are.equal(4, line:pos_char())
      assert.are.equal(5, line:pos_col())
    end)


    it("moves the cursor to the start if index is 1", function()
      local line = Utf8edit("hello")
      line:goto_index(1):insert("1你")
      assert.are.equal("1你hello", tostring(line))
      assert.are.equal(3, line:pos_char())
      assert.are.equal(4, line:pos_col())
    end)


    it("moves the cursor to the end if index is greater than length", function()
      local line = Utf8edit("hello")
      line:goto_index(10)
      assert.are.equal(6, line:pos_char())
      assert.are.equal(6, line:pos_col())
    end)


    it("does nothing if the string is empty", function()
      local line = Utf8edit("")
      line:goto_index(3)
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)


    it("handles negative indices correctly", function()
      local line = Utf8edit("hello")
      line:goto_index(-3)  -- should go to second last character
      line:insert("X")
      assert.are.equal("helXlo", tostring(line))
      assert.are.equal(5, line:pos_char())
      assert.are.equal(5, line:pos_col())
    end)


    it("moves to start if negative index is less than -length", function()
      local line = Utf8edit("hello")
      line:goto_index(-10)  -- should go to start
      line:insert("X")
      assert.are.equal("Xhello", tostring(line))
      assert.are.equal(2, line:pos_char())
      assert.are.equal(2, line:pos_col())
    end)

  end)



  describe("complex string edits", function()

    it("handles left and right cursor movements with UTF-8", function()
      local line = Utf8edit("你好世界")
      line:left(2):insert("！")
      assert.are.equal(7, line:pos_col())
      assert.are.equal(4, line:pos_char())
      assert.are.equal("你好！世界", tostring(line))
    end)


    it("handles backspace correctly", function()
      local line = Utf8edit("hello")
      line:left(2):backspace()
      assert.are.equal(3, line:pos_char())
      assert.are.equal("helo", tostring(line))
    end)


    it("handles backspace correctly with UTF-8", function()
      local line = Utf8edit("你好世界")
      line:left(2):backspace()
      assert.are.equal(2, line:pos_char())
      assert.are.equal(3, line:pos_col())
      assert.are.equal("你世界", tostring(line))
    end)


    it("handles delete correctly", function()
      local line = Utf8edit("hello")
      line:left(2):delete()
      assert.are.equal(4, line:pos_char())
      assert.are.equal("helo", tostring(line))
    end)


    it("handles delete correctly with UTF-8", function()
      local line = Utf8edit("你好世界")
      line:left(2):delete()
      assert.are.equal("你好界", tostring(line))
      assert.are.equal(3, line:pos_char())
      assert.are.equal(5, line:pos_col())
    end)


    it("handles a sequence of edits", function()
      local line = Utf8edit("hello")
      line:left(2):backspace():insert("y"):right():insert("!")
      assert.are.equal(6, line:pos_char())
      assert.are.equal("heyl!o", tostring(line))
    end)


    it("handles a sequence of edits with UTF-8", function()
      local line = Utf8edit("你好世界")
      line:left(2):backspace():insert("a"):right():insert("！")
      assert.are.equal(8, line:pos_col())
      assert.are.equal(5, line:pos_char())
      assert.are.equal("你a世！界", tostring(line))
    end)


    it("handles spamming of keys", function()
      local line = Utf8edit("你好世界")
      line:left(10):backspace(3)
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
      line:right(13):delete(3)
      assert.are.equal(5, line:pos_char())
      assert.are.equal(9, line:pos_col())
      assert.are.equal("你好世界", tostring(line))
    end)

  end)



  describe("clear()", function()

    it("clears the line", function()
      local line = Utf8edit("hello")
      line:clear()
      assert.are.equal("", tostring(line))
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)


    it("does nothing if the line is already empty", function()
      local line = Utf8edit("")
      line:clear()
      assert.are.equal("", tostring(line))
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)

  end)



  describe("replace()", function()

    it("replaces the line with a new ASCII string", function()
      local line = Utf8edit("hello")
      line:replace("world")
      assert.are.equal("world", tostring(line))
      assert.are.equal(6, line:pos_char())
      assert.are.equal(6, line:pos_col())
    end)


    it("replaces the line with a new UTF-8 string", function()
      local line = Utf8edit("hello")
      line:replace("你好")
      assert.are.equal("你好", tostring(line))
      assert.are.equal(3, line:pos_char())
      assert.are.equal(5, line:pos_col())
    end)


    it("replaces the line with an empty string", function()
      local line = Utf8edit("hello")
      line:replace("")
      assert.are.equal("", tostring(line))
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)

  end)



  describe("backspace_to_start()", function()

    it("removes all characters to the left of the cursor", function()
      local line = Utf8edit("hello world")
      line:left(6) -- move cursor after 'hello'
      line:backspace_to_start()
      assert.are.equal(" world", tostring(line))
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)


    it("does nothing if cursor is at the start", function()
      local line = Utf8edit("hello")
      line:goto_home()
      line:backspace_to_start()
      assert.are.equal("hello", tostring(line))
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)

  end)



  describe("delete_to_end()", function()

    it("removes all characters to the right of the cursor", function()
      local line = Utf8edit("hello world")
      line:left(6) -- move cursor after 'hello'
      line:delete_to_end()
      assert.are.equal("hello", tostring(line))
      assert.are.equal(6, line:pos_char())
      assert.are.equal(6, line:pos_col())
    end)


    it("removes all characters to the right of the cursor (UTF-8)", function()
      local line = Utf8edit("你好世界abc")
      line:left(5) -- move cursor after '你好'
      line:delete_to_end()
      assert.are.equal("你好", tostring(line))
      assert.are.equal(3, line:pos_char())
      assert.are.equal(5, line:pos_col())
    end)


    it("does nothing if cursor is at the end", function()
      local line = Utf8edit("hello")
      line:goto_end():delete_to_end()
      assert.are.equal("hello", tostring(line))
      assert.are.equal(6, line:pos_char())
      assert.are.equal(6, line:pos_col())
    end)

  end)



  describe("left_word()", function()

    it("moves the cursor to the start of the previous word (ASCII)", function()
      local line = Utf8edit("hello world")
      line:left_word()
      assert.are.equal(7, line:pos_char())  -- cursor should be at the start of "world"
      assert.are.equal(7, line:pos_col())
    end)


    it("moves the cursor to the start of the previous word (UTF-8)", function()
      local line = Utf8edit("你好 thế giới")
      line:left_word()
      assert.are.equal(8, line:pos_char())  -- cursor should be at the start of "giới"
      assert.are.equal(10, line:pos_col())
    end)


    it("moves to the beginning of the line if cursor is already at the first word", function()
      local line = Utf8edit("hello world")
      line:goto_home():right(2):left_word()
      assert.are.equal(1, line:pos_char()) -- cursor should be at the beginning
      assert.are.equal(1, line:pos_col())
    end)


    it("does nothing if cursor is already at the beginning", function()
      local line = Utf8edit("hello world")
      line:goto_home():left_word()
      assert.are.equal(1, line:pos_char()) -- cursor should stay at the beginning
      assert.are.equal(1, line:pos_col())
    end)


    it("ignore consecutive spaces", function()
      local line = Utf8edit("hello.()''''''][]   world")
      line:left_word()
      assert.are.equal(21, line:pos_char()) -- cursor should be at the start of "world"
      assert.are.equal(21, line:pos_col())
    end)


    it("skips over consecutive spaces", function()
      local line = Utf8edit("(╯°□°) ╯︵        ┻━┻)")
      --                            |          ^ 1st left_word()
      --                            ^ 2nd left_word()
      line:left_word(2)
      assert.are.equal(8, line:pos_char())
      assert.are.equal(8, line:pos_col())
    end)


    it("go to line start if there's only delimiters to the left ", function()
      local line = Utf8edit("([[._.]]）-------  ┻━┻)")
      line:left_word(4)
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)


    it("does nothing if the string is empty", function()
      local line = Utf8edit("")
      line:left_word()
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)

  end)



  describe("right_word()", function()

    it("moves the cursor to the start of the next word (ASCII)", function()
      local line = Utf8edit("hello world")
      line:goto_home():right_word()
      assert.are.equal(7, line:pos_char())  -- cursor should be at the end of "hello"
      assert.are.equal(7, line:pos_col())
    end)


    it("moves the cursor to the end of the next word (UTF-8)", function()
      local line = Utf8edit("你好 thế giới")
      line:goto_home():right_word()
      assert.are.equal(4, line:pos_char())  -- cursor should be at the end of "你好"
      assert.are.equal(6, line:pos_col())
    end)


    it("moves to the end of the line if cursor is already at the last word", function()
      local line = Utf8edit("hello world")
      line:goto_index(8):right_word()
      assert.are.equal(12, line:pos_char()) -- cursor should be at the end
      assert.are.equal(12, line:pos_col())
    end)


    it("does nothing if cursor is already at the end", function()
      local line = Utf8edit("hello world")
      line:goto_end():right_word()
      assert.are.equal(12, line:pos_char()) -- cursor should stay at the end
      assert.are.equal(12, line:pos_col())
    end)


    it("skips over consecutive spaces", function()
      local line = Utf8edit("hello***-.-***   world")
      line:goto_home():right_word()
      assert.are.equal(18, line:pos_char()) -- cursor should be at the start of "world"
      assert.are.equal(18, line:pos_col())
    end)


    it("does nothing if the string is empty", function()
      local line = Utf8edit("")
      line:right_word()
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)
  end)



  describe("backspace_word()", function()

    it("deletes the word to the left of the cursor (ASCII)", function()
      local line = Utf8edit("hello my world")
      line:left_word():backspace_word()
      assert.are.equal("hello world", tostring(line))  -- "my" should be deleted
      assert.are.equal(7, line:pos_char())
      assert.are.equal(7, line:pos_col())
    end)


    it("deletes the word to the left of the cursor (UTF-8)", function()
      local line = Utf8edit("你好 thế giới")
      line:left_word():backspace_word()
      assert.are.equal("你好 giới", tostring(line)) -- "thế" should be deleted
      assert.are.equal(4, line:pos_char())
      assert.are.equal(6, line:pos_col())
    end)


    it("does nothing if cursor is at the beginning", function()
      local line = Utf8edit("hello world")
      line:goto_home():backspace_word()
      assert.are.equal("hello world", tostring(line))
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)


    it("deletes previous word over multiple spaces if at start", function()
      local line = Utf8edit("hello.....   world")
      line:left_word():backspace_word()
      assert.are.equal("world", tostring(line))
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)


    it("deletes partial word if cursor is in middle of word", function()
      local line = Utf8edit("hello world")
      line:goto_index(9):backspace_word()
      assert.are.equal("hello rld", tostring(line))
      assert.are.equal(7, line:pos_char())
      assert.are.equal(7, line:pos_col())
    end)


    it("does nothing if the string is empty", function()
      local line = Utf8edit("")
      line:backspace_word()
      assert.are.equal("", tostring(line))
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)

  end)



  describe("delete_word()", function()

    it("deletes the word to the right of the cursor (ASCII)", function()
      local line = Utf8edit("hello my world")
      line:left_word(2):delete_word()
      assert.are.equal("hello  world", tostring(line))  -- "my" should be deleted
      assert.are.equal(7, line:pos_char())
      assert.are.equal(7, line:pos_col())
    end)


    it("deletes the word to the right of the cursor (UTF-8)", function()
      local line = Utf8edit("你好 thế giới")
      line:left_word(2):delete_word()
      assert.are.equal("你好  giới", tostring(line)) -- "thế" should be deleted
      assert.are.equal(4, line:pos_char())
      assert.are.equal(6, line:pos_col())
    end)


    it("does nothing if cursor is at the end", function()
      local line = Utf8edit("hello world")
      line:goto_end():delete_word()
      assert.are.equal("hello world", tostring(line))
      assert.are.equal(12, line:pos_char())
      assert.are.equal(12, line:pos_col())
    end)


    it("deletes partial word if cursor is in middle of word", function()
      local line = Utf8edit("hello world beautiful")
      line:goto_index(8):delete_word()
      assert.are.equal("hello w beautiful", tostring(line))
      assert.are.equal(8, line:pos_char())
      assert.are.equal(8, line:pos_col())
    end)


    it("deletes all delimiters if there's only delimiters to the right", function()
      local line = Utf8edit("hello  -?:: :::**")
      line:goto_index(7):delete_word()
      assert.are.equal("hello ", tostring(line))
      assert.are.equal(7, line:pos_char())
      assert.are.equal(7, line:pos_col())
    end)


    it("does nothing if the string is empty", function()
      local line = Utf8edit("")
      line:delete_word()
      assert.are.equal("", tostring(line))
      assert.are.equal(1, line:pos_char())
      assert.are.equal(1, line:pos_col())
    end)

  end)

end)
