describe("EditLine:", function()

  local EditLine

  before_each(function()
    _G._TEST = true
    EditLine = require("terminal.editline")
  end)


  after_each(function()
    EditLine = nil
    _G._TEST = nil
  end)



  describe("get_non_wrapped_line()", function()

    it("returns full string if less than size", function()
      local line = EditLine("Hello, world!"):goto_home()
      local target_size = line:len_col() + 5 -- 5 extra columnss
      local result, cols = line:_get_non_wrapped_line(target_size)
      assert.are.equal("Hello, world!", tostring(result))
      assert.are.equal(13, cols)
    end)


    it("returns full string if equal to size", function()
      local line = EditLine("Hello, world!"):goto_home()
      local target_size = line:len_col()
      local result, cols = line:_get_non_wrapped_line(target_size)
      assert.are.equal("Hello, world!", tostring(result))
      assert.are.equal(13, cols)
    end)


    it("returns error if size is less than 2", function()
      local line = EditLine("Hello, world!"):goto_home()
      local target_size = 1
      assert.has.error(function()
        line:_get_non_wrapped_line(target_size)
      end, "target_size must be 2 or greater")
    end)


    it("returns empty string if string is empty", function()
      local line = EditLine(""):goto_home()
      local target_size = 15
      local result, cols = line:_get_non_wrapped_line(target_size)
      assert.are.equal("", tostring(result))
      assert.are.equal(0, cols)
    end)


    it("returns empty string if cursor is at the end", function()
      local line = EditLine("hello world!"):goto_end()
      local target_size = 15
      local result, cols = line:_get_non_wrapped_line(target_size)
      assert.are.equal("", tostring(result))
      assert.are.equal(0, cols)
    end)


    it("returns string up to target size if larger than size", function()
      local line = EditLine("Hello, world!"):goto_home()
      local target_size = 5
      local result, cols = line:_get_non_wrapped_line(target_size)
      assert.are.equal("Hello", tostring(result))
      assert.are.equal(5, cols)
    end)


    it("doesn't include doublewidth char at the edge", function()
      local line = EditLine("Hello, 世界!")

      -- up to double-width character
      line:goto_home()
      local target_size = 7
      local result, cols = line:_get_non_wrapped_line(target_size)
      assert.are.equal("Hello, ", tostring(result))
      assert.are.equal(7, cols)
      assert.are.equal(8, line:pos_char()) -- cursor is on the double-width character

      -- skips the double width character if it doesn't fit
      line:goto_home()
      local target_size = 8
      local result, cols = line:_get_non_wrapped_line(target_size)
      assert.are.equal("Hello, ", tostring(result))
      assert.are.equal(7, cols)
      assert.are.equal(8, line:pos_char()) -- cursor is on the double-width character

      -- includes the double width character if it fits
      line:goto_home()
      local target_size = 9
      local result, cols = line:_get_non_wrapped_line(target_size)
      assert.are.equal("Hello, 世", tostring(result))
      assert.are.equal(9, cols)
      assert.are.equal(9, line:pos_char()) -- cursor is on the double-width character
    end)


    it("result string starts at current cursor position", function()
      local line = EditLine("Hello, world!"):goto_home()
      local target_size = 10
      line:right(7) -- move cursor to 'w'
      local result, cols = line:_get_non_wrapped_line(target_size)
      assert.are.equal("world!", tostring(result))
      assert.are.equal(6, cols) -- only 'world!' is returned
    end)

  end)



  describe("get_wrapped_line()", function()

    local text

    local function testwrap(width)
      local fullline = EditLine(text):goto_home()
      local formatted = {}
      while fullline:pos_char() < fullline:len_char() do
        local line, cols = fullline:_get_wrapped_line(width)
        formatted[#formatted+1] = tostring(line).."("..tostring(cols)..")"
      end
      return formatted
    end


    before_each(function()
      text = "Hello, this is a simple 🚀 test string to check the formatting function of " ..
             "the EditLine class."
    end)


    it("returns full string if less than size", function()
      local line = EditLine("Hello, world!"):goto_home()
      local target_size = line:len_col() + 5 -- 5 extra columnss
      local result, cols = line:_get_wrapped_line(target_size)
      assert.are.equal("Hello, world!", tostring(result))
      assert.are.equal(13, cols)
    end)


    it("returns full string if equal to size", function()
      local line = EditLine("Hello, world!"):goto_home()
      local target_size = line:len_col()
      local result, cols = line:_get_wrapped_line(target_size)
      assert.are.equal("Hello, world!", tostring(result))
      assert.are.equal(13, cols)
    end)


    it("returns error if size is less than 2", function()
      local line = EditLine("Hello, world!"):goto_home()
      local target_size = 1
      assert.has.error(function()
        line:_get_wrapped_line(target_size)
      end, "target_size must be 2 or greater")
    end)


    it("returns empty string if string is empty", function()
      local line = EditLine(""):goto_home()
      local target_size = 15
      local result, cols = line:_get_wrapped_line(target_size)
      assert.are.equal("", tostring(result))
      assert.are.equal(0, cols)
    end)


    it("returns empty string if cursor is at the end", function()
      local line = EditLine("hello world!"):goto_end()
      local target_size = 15
      local result, cols = line:_get_wrapped_line(target_size)
      assert.are.equal("", tostring(result))
      assert.are.equal(0, cols)
    end)


    it("wraps words", function()
      local line = EditLine("hello 🚀 world! hello 🚀 world!")

      line:goto_home()
      local target_size = 13 -- l in world
      local result, cols = line:_get_wrapped_line(target_size)
      assert.are.equal("hello 🚀 ", tostring(result))
      assert.are.equal(9, cols)

      line:goto_home()
      local target_size = 14 -- d in world
      local result, cols = line:_get_wrapped_line(target_size)
      assert.are.equal("hello 🚀 ", tostring(result))
      assert.are.equal(9, cols)

      line:goto_home()
      local target_size = 15 -- ! after world
      local result, cols = line:_get_wrapped_line(target_size)
      assert.are.equal("hello 🚀 world!", tostring(result))
      assert.are.equal(15, cols)

      line:goto_home()
      local target_size = 16 -- ' ' after world!
      local result, cols = line:_get_wrapped_line(target_size)
      assert.are.equal("hello 🚀 world! ", tostring(result))
      assert.are.equal(16, cols)

      line:goto_home()
      local target_size = 17 -- 'h' after world!
      local result, cols = line:_get_wrapped_line(target_size)
      assert.are.equal("hello 🚀 world! ", tostring(result))
      assert.are.equal(16, cols)
    end)


    it("wraps words on double-width edges", function()
      local line = EditLine("hello 🚀 world! hello 🚀 world!")

      line:goto_home()
      local target_size = 9 -- ' ' after 🚀
      local result, cols = line:_get_wrapped_line(target_size)
      assert.are.equal("hello 🚀 ", tostring(result))
      assert.are.equal(9, cols)

      line:goto_home()
      local target_size = 8
      local result, cols = line:_get_wrapped_line(target_size)
      assert.are.equal("hello ", tostring(result))
      assert.are.equal(6, cols)
    end)


    it("wraps multiple lines", function()
      assert.same({
      --'--------------------(20)'
        'Hello, this is a (17)',
        'simple 🚀 test (15)',
        'string to check the (20)',
        'formatting function (20)',
        'of the EditLine (16)',
        'class.(6)',
      }, testwrap(20))
    end)


    it("wraps at the right edge, including delimiter on line", function()
      assert.same({
      --'-------------------(19)' after 'si' of simple
        'Hello, this is a (17)',
        'simple 🚀 test (15)',
        'string to check (16)',
        'the formatting (15)',
        'function of the (16)',
        'EditLine class.(15)',
      }, testwrap(19))

      assert.same({
      --'------------------(18)' after 's' of simple
        'Hello, this is a (17)',
        'simple 🚀 test (15)',
        'string to check (16)',
        'the formatting (15)',
        'function of the (16)',
        'EditLine class.(15)',
      }, testwrap(18))

      assert.same({
      --'-----------------(17)' after ' ' between 'a' and 'simple'
        'Hello, this is a (17)',
        'simple 🚀 test (15)',
        'string to check (16)',
        'the formatting (15)',
        'function of the (16)',
        'EditLine class.(15)',
      }, testwrap(17))

      assert.same({
      --'----------------(16)' on ' ' between 'a' and 'simple'
        'Hello, this is (15)',
        'a simple 🚀 (12)',
        'test string to (15)',
        'check the (10)',
        'formatting (11)',
        'function of the (16)',
        'EditLine class.(15)',
      }, testwrap(16))

      assert.same({
      --'---------------(15)' on 'a' before 'simple'
        'Hello, this is (15)',
        'a simple 🚀 (12)',
        'test string to (15)',
        'check the (10)',
        'formatting (11)',
        'function of (12)',
        'the EditLine (13)',
        'class.(6)',
      }, testwrap(15))

    end)


    it("wraps single word over multiple lines if required", function()
      text = "ThisIsQuiteALongWord"
      assert.same({
        'ThisIs(6)',
        'QuiteA(6)',
        'LongWo(6)',
        'rd(2)',
      }, testwrap(6))
    end)

  end)



  describe("pad_line()", function()

    it("pads a line whilst retaining cursor position", function()
      local line = EditLine("hello world!"):goto_index(6)
      line:_pad_line(line:len_col(), 20)
      assert.equal("hello world!        ", tostring(line))
      assert.equal(6, line:pos_char())
    end)


    it("pads a line containing double width chars", function()
      local line = EditLine("hello 🚀🚀🚀 world!"):goto_index(6)
      line:_pad_line(line:len_col(), 20)
      assert.equal("hello 🚀🚀🚀 world! ", tostring(line))
      assert.equal(6, line:pos_char())
    end)


    it("does nothing if the line is already at the number of columns", function()
      local line = EditLine("hello world!"):goto_index(6)
      line:_pad_line(line:len_col(), 10)
      assert.equal("hello world!", tostring(line))
      assert.equal(6, line:pos_char())
    end)

  end)



  describe("format()", function()

    local text, line

    local function testwrap(opts)
      local formatted, row, col = line:format(opts)
      for i, line in ipairs(formatted) do
        line:insert("|") -- insert in the Editline object, to mark cursor pos
        formatted[i] = tostring(line)
      end
      return formatted, row, col
    end


    before_each(function()
      text = "Hello, this is a simple 🚀 test string to check the formatting functionality of " ..
             "the EditLine class. It features word wrapping, padding, and cursor handling. " ..
             "The class supports both single-width and double-width characters, ensuring " ..
             "correct column calculations 🚀."
      line = EditLine(text):goto_index(80)
    end)


    describe("no-wrap", function()

      it("formats a string", function()
        local lines = testwrap({
          width = 60,
          first_width = 60,
          wordwrap = false,
          pad = false,
          pad_last = false
        })

        assert.are.same({
          'Hello, this is a simple 🚀 test string to check the formatti|',
          'ng functionality of |the EditLine class. It features word wra',
          'pping, padding, and cursor handling. The class supports both|',
          ' single-width and double-width characters, ensuring correct |',
          'column calculations 🚀.|',
        }, lines)

        -- check cursor position, insert cursor pos in original line object
        line:insert("|")
        -- now line 2 of the formatted object must be found in the original 'tostringed' one
        assert(tostring(line):find(lines[2], 1, true), "expected cursor positions to match")
      end)


      it("formats a string with padding", function()
        assert.are.same({
          'Hello, this is a simple 🚀 test string to check the formatti|',
          'ng functionality of |the EditLine class. It features word wra',
          'pping, padding, and cursor handling. The class supports both|',
          ' single-width and double-width characters, ensuring correct |',
          'column calculations 🚀.|',
        }, testwrap({
          width = 60,
          first_width = 60,
          wordwrap = false,
          pad = true,
          pad_last = false
        }))

        assert.are.same({
          'Hello, this is a simple 🚀 test string to check the formatti|',
          'ng functionality of |the EditLine class. It features word wra',
          'pping, padding, and cursor handling. The class supports both|',
          ' single-width and double-width characters, ensuring correct |',
          'column calculations 🚀.|                                     ',
        }, testwrap({
          width = 60,
          first_width = 60,
          wordwrap = false,
          pad = false,
          pad_last = true
        }))

        assert.are.same({
          'Hello, this is a simple 🚀 test string to check the formatti|',
          'ng functionality of |the EditLine class. It features word wra',
          'pping, padding, and cursor handling. The class supports both|',
          ' single-width and double-width characters, ensuring correct |',
          'column calculations 🚀.|                                     ',
        }, testwrap({
          width = 60,
          first_width = 60,
          wordwrap = false,
          pad = true,
          pad_last = true
        }))

        assert.are.same({
          'Hello, this is a simple 🚀 test string to check the for|',
          'matting functionality of |the EditLine class. It features wor',
          'd wrapping, padding, and cursor handling. The class supports|',
          ' both single-width and double-width characters, ensuring cor|',
          'rect column calculations 🚀.|',
        }, testwrap({
          width = 60,
          first_width = 55, -- deviating first-line
          wordwrap = false,
          pad = true,
          pad_last = false
        }))
      end)


      it("single result-line padding", function()
        line = EditLine("will go into a single line"):goto_index(10)
        assert.are.same({
          'will go i|nto a single line',
        }, testwrap({
          width = 30,
          first_width = 30,
          wordwrap = false,
          pad = false,
          pad_last = false
        }))

        assert.are.same({
          'will go i|nto a single line',
        }, testwrap({
          width = 30,
          first_width = 30,
          wordwrap = false,
          pad = true,
          pad_last = false
        }))

        assert.are.same({
          'will go i|nto a single line    ',
        }, testwrap({
          width = 30,
          first_width = 30,
          wordwrap = false,
          pad = false,
          pad_last = true
        }))

        assert.are.same({
          'will go i|nto a single line ',
        }, testwrap({
          width = 30,
          first_width = 27,  -- deviating
          wordwrap = false,
          pad = false,
          pad_last = true
        }))
      end)



      describe("cursor-position", function()

        it("puts cursor in proper position", function()
          line = EditLine("will go into a single line"):goto_index(10)
          local expected = tostring(line:insert("|"))
          line:backspace() -- remove inserted cgar again
          assert.are.equal('will go i|nto a single line', expected)

          assert.are.same({
            expected,
          }, testwrap({
            width = 30,
            first_width = 30,
            wordwrap = false,
            pad = false,
            pad_last = false
          }))
        end)


        it("moves cursor to start of next line if at the end", function()
          local pos = 10
          line = EditLine("will go into a single line (not really)"):goto_index(pos)
          assert.are.same({
            'will go i|',
            '|nto a sin',
            'gle line |',
            '(not real|',
            'ly)|',
          }, testwrap({
            width = pos-1,  -- cursor is one beyond last char, so length is one less
            first_width = pos-1,
            wordwrap = false,
            pad = false,
            pad_last = false
          }))
        end)


        it("moves cursor to start of next line if at the end of shorted first line", function()
          local pos = 10
          line = EditLine("will go into a single line (not really)"):goto_index(pos)
          assert.are.same({
            'will go i|',
            '|nto a single li',
            'ne (not really)|',
          }, testwrap({
            width = pos+5, -- other lines are longer
            first_width = pos-1,  -- cursor is one beyond last char, so length is one less
            wordwrap = false,
            pad = false,
            pad_last = false
          }))
        end)


        it("adds new line if cursor is at the end of the last line", function()
          line = EditLine("some test data"):goto_end():left(2)
          assert.are.same({
            {
              'some test da|ta'
            },
            1,
            13,
          }, {testwrap({
            width = 14,
            first_width = 14,
            wordwrap = false,
            pad = false,
            pad_last = false
          })})

          line = EditLine("some test data"):goto_end():left(1)
          assert.are.same({
            {
              'some test dat|a'
            },
            1,
            14,
          }, {testwrap({
            width = 14,
            first_width = 14,
            wordwrap = false,
            pad = false,
            pad_last = false
          })})

          line = EditLine("some test data"):goto_end()
          assert.are.same({
            'some test data|',
            '|',
          }, testwrap({
            width = 14,
            first_width = 14,
            wordwrap = false,
            pad = false,
            pad_last = false
          }))

          -- again with multiple lines
          line = EditLine("sometestdata"):goto_end():left(2)
          assert.are.same({
            'some|',
            'test|',
            'da|ta',
          }, testwrap({
            width = 4,
            first_width = 4,
            wordwrap = false,
            pad = false,
            pad_last = false
          }))

          line = EditLine("sometestdata"):goto_end():left(1)
          assert.are.same({
            'some|',
            'test|',
            'dat|a',
          }, testwrap({
            width = 4,
            first_width = 4,
            wordwrap = false,
            pad = false,
            pad_last = false
          }))

          line = EditLine("sometestdata"):goto_end()
          assert.are.same({
            'some|',
            'test|',
            'data|',
            '|',
          }, testwrap({
            width = 4,
            first_width = 4,
            wordwrap = false,
            pad = false,
            pad_last = false
          }))

        end)


        it("doesn't add new line if cursor is at the end of a non-oversized last line", function()
          -- single line
          line = EditLine("some test data"):goto_end()
          assert.are.same({
            {
              'some test data|'
            },
            1,
            15,
          }, {testwrap({
            width = 20,
            first_width = 20,
            wordwrap = false,
            pad = false,
            pad_last = false
          })})

          -- again with multiple lines
          line = EditLine("sometestda"):goto_end()
          assert.are.same({
            {
              'some|',
              'test|',
              'da|',
            },
            3,
            3,
          }, {testwrap({
            width = 4,
            first_width = 4,
            wordwrap = false,
            pad = false,
            pad_last = false
          })})
        end)


        it("doesn't add the extra newline if set to do so", function()
          line = EditLine("sometestdata"):goto_end()
          assert.are.same({
            'some|',
            'test|',
            'data|',
          }, testwrap({
            width = 4,
            first_width = 4,
            wordwrap = false,
            pad = false,
            pad_last = false,
            no_new_cursor_line = true,
          }))
        end)

      end)

    end)



    describe("word-wrap", function()

      it("formats a string", function()
        local lines = testwrap({
          width = 60,
          first_width = 60,
          wordwrap = true,
          pad = false,
          pad_last = false
        })

        assert.are.same({
          'Hello, this is a simple 🚀 test string to check the |',
          'formatting functionality of |the EditLine class. It features ',
          'word wrapping, padding, and cursor handling. The class |',
          'supports both single-width and double-width characters, |',
          'ensuring correct column calculations 🚀.|',
        --'                                                            |'   just to check allowed width
        }, lines)

        -- check cursor position, insert cursor pos in original line object
        line:insert("|")
        -- now line 2 of the formatted object must be found in the original 'tostringed' one
        assert(tostring(line):find(lines[2], 1, true), "expected cursor positions to match")
      end)


      it("formats a string with padding", function()
        assert.are.same({
          'Hello, this is a simple 🚀 test string to check the |        ',
          'formatting functionality of |the EditLine class. It features ',
          'word wrapping, padding, and cursor handling. The class |     ',
          'supports both single-width and double-width characters, |    ',
          'ensuring correct column calculations 🚀.|',
        }, testwrap({
          width = 60,
          first_width = 60,
          wordwrap = true,
          pad = true,
          pad_last = false
        }))

        assert.are.same({
          'Hello, this is a simple 🚀 test string to check the |',
          'formatting functionality of |the EditLine class. It features ',
          'word wrapping, padding, and cursor handling. The class |',
          'supports both single-width and double-width characters, |',
          'ensuring correct column calculations 🚀.|                    ',
        }, testwrap({
          width = 60,
          first_width = 60,
          wordwrap = true,
          pad = false,
          pad_last = true
        }))

        assert.are.same({
          'Hello, this is a simple 🚀 test string to check the |        ',
          'formatting functionality of |the EditLine class. It features ',
          'word wrapping, padding, and cursor handling. The class |     ',
          'supports both single-width and double-width characters, |    ',
          'ensuring correct column calculations 🚀.|                    ',
        }, testwrap({
          width = 60,
          first_width = 60,
          wordwrap = true,
          pad = true,
          pad_last = true
        }))

        assert.are.same({
          'Hello, this is a simple 🚀 test string to check the |   ',
          'formatting functionality of |the EditLine class. It features ',
          'word wrapping, padding, and cursor handling. The class |     ',
          'supports both single-width and double-width characters, |    ',
          'ensuring correct column calculations 🚀.|',
        }, testwrap({
          width = 60,
          first_width = 55, -- deviating first-line
          wordwrap = true,
          pad = true,
          pad_last = false
        }))
      end)


      it("single result-line padding", function()
        line = EditLine("will go into a single line"):goto_index(10)
        assert.are.same({
          'will go i|nto a single line',
        }, testwrap({
          width = 30,
          first_width = 30,
          wordwrap = true,
          pad = false,
          pad_last = false
        }))

        assert.are.same({
          'will go i|nto a single line',
        }, testwrap({
          width = 30,
          first_width = 30,
          wordwrap = true,
          pad = true,
          pad_last = false
        }))

        assert.are.same({
          'will go i|nto a single line    ',
        }, testwrap({
          width = 30,
          first_width = 30,
          wordwrap = true,
          pad = false,
          pad_last = true
        }))

        assert.are.same({
          'will go i|nto a single line ',
        }, testwrap({
          width = 30,
          first_width = 27,  -- deviating
          wordwrap = true,
          pad = false,
          pad_last = true
        }))
      end)



      describe("cursor-position", function()

        it("puts cursor in proper position", function()
          line = EditLine("will go into a single line"):goto_index(14)
          local expected = tostring(line:insert("|"))
          line:backspace() -- remove inserted cgar again
          assert.are.equal('will go into |a single line', expected)

          assert.are.same({
            expected
          }, testwrap({
            width = 30,
            first_width = 30,
            wordwrap = true,
            pad = false,
            pad_last = false
          }))
        end)


        it("moves cursor to start of next line if at the end", function()
          local pos = 14
          line = EditLine("will go into a single line (not really)"):goto_index(pos)
          assert.are.same({
            'will go into |',
            '|a single ',
            'line (not |',
            'really)|',
          }, testwrap({
            width = pos-1,  -- cursor is one beyond last char, so length is one less
            first_width = pos-1,
            wordwrap = true,
            pad = false,
            pad_last = false
          }))
        end)


        it("moves cursor to start of next line if at the end of shorted first line", function()
          local pos = 9
          line = EditLine("will go into a single line (not really)"):goto_index(pos)
          assert.are.same({
            'will go |',
            '|into a single line (',
            'not really)|',
          }, testwrap({
            width = 20, -- other lines are longer
            first_width = 10,  -- cursor is one beyond last char, so length is one less
            wordwrap = true,
            pad = false,
            pad_last = false
          }))
        end)


        it("adds new line if cursor is at the end of the last line", function()
          line = EditLine("some test data"):goto_end():left(2)
          assert.are.same({
            {
              'some test da|ta'
            },
            1,
            13,
          }, {testwrap({
            width = 14,
            first_width = 14,
            wordwrap = true,
            pad = false,
            pad_last = false
          })})

          line = EditLine("some test data"):goto_end():left(1)
          assert.are.same({
            {
              'some test dat|a'
            },
            1,
            14,
          }, {testwrap({
            width = 14,
            first_width = 14,
            wordwrap = true,
            pad = false,
            pad_last = false
          })})

          line = EditLine("some test data"):goto_end()
          assert.are.same({
            'some test data|',
            '|',
          }, testwrap({
            width = 14,
            first_width = 14,
            wordwrap = true,
            pad = false,
            pad_last = false
          }))

          -- again with multiple lines
          line = EditLine("sometestdata"):goto_end():left(2)
          assert.are.same({
            'some|',
            'test|',
            'da|ta',
          }, testwrap({
            width = 4,
            first_width = 4,
            wordwrap = true,
            pad = false,
            pad_last = false
          }))

          line = EditLine("sometestdata"):goto_end():left(1)
          assert.are.same({
            'some|',
            'test|',
            'dat|a',
          }, testwrap({
            width = 4,
            first_width = 4,
            wordwrap = true,
            pad = false,
            pad_last = false
          }))

          line = EditLine("sometestdata"):goto_end()
          assert.are.same({
            'some|',
            'test|',
            'data|',
            '|',
          }, testwrap({
            width = 4,
            first_width = 4,
            wordwrap = true,
            pad = false,
            pad_last = false
          }))

        end)


        it("doesn't add new line if cursor is at the end of a non-oversized last line", function()
          -- single line
          line = EditLine("some test data"):goto_end()
          assert.are.same({
            {
              'some test data|'
            },
            1,
            55,
          }, {testwrap({
            width = 60,
            first_width = 20,
            wordwrap = true,
            pad = false,
            pad_last = false
          })})

          -- again with multiple lines
          line = EditLine("somexx testxx data"):goto_end()
          assert.are.same({
            {
              'somexx |',
              'testxx |',
              'data|',
            },
            3,
            5,
          }, {testwrap({
            width = 8,
            first_width = 8,
            wordwrap = true,
            pad = false,
            pad_last = false
          })})
        end)


        it("doesn't add the extra newline if set to do so", function()
          line = EditLine("some testdata"):goto_end()
          assert.are.same({
            'some |',
            'testdata|',
          }, testwrap({
            width = 8,
            first_width = 8,
            wordwrap = true,
            pad = false,
            pad_last = false,
            no_new_cursor_line = true,
          }))
        end)

      end)

    end)

  end)

end)
