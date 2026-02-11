describe("utils.utf8sub_col()", function()

  local utils

  before_each(function()
    utils = require("terminal.utils")
  end)


  after_each(function()
    utils = nil
  end)


  do
    local test_cases = {
      -- Basic ASCII tests
      {"hello", 1, 5, false, "hello", "extracts full ASCII string"},
      {"hello", 2, 4, false, "ell", "extracts middle of ASCII string"},
      {"hello", 1, 3, false, "hel", "extracts start of ASCII string"},
      {"hello", 3, 5, false, "llo", "extracts end of ASCII string"},
      {"hello", 1, 1, false, "h", "extracts single character from ASCII"},
      {"hello", 6, 10, false, "", "returns empty string when start beyond string"},
      {"hello", 3, 2, false, "", "returns empty string when j < i"},

      -- UTF-8 single-width character tests
      {"héllo", 1, 5, false, "héllo", "extracts full UTF-8 string with single-width chars"},
      {"héllo", 2, 4, false, "éll", "extracts middle of UTF-8 string"},
      {"café", 1, 4, false, "café", "extracts full UTF-8 string ending with accent"},

      -- UTF-8 double-width character tests
      {"你好", 1, 4, false, "你好", "extracts full double-width UTF-8 string"},
      {"你好", 1, 2, false, "你", "extracts first double-width character"},
      {"你好", 3, 4, false, "好", "extracts second double-width character"},
      {"你好世界", 3, 6, false, "好世", "extracts middle double-width characters"},

      -- Mixed single and double-width character tests
      {"a你b好c", 1, 7, false, "a你b好c", "extracts mixed single and double-width characters"},
      {"a你b好c", 2, 4, false, "你b", "extracts mixed characters from middle"},
      {"a你b好c", 1, 3, false, "a你", "extracts mixed characters from start"},
      {"a你b好c", 5, 7, false, "好c", "extracts mixed characters from end"},

      -- Padding tests (no_pad = false)
      {"你好", 2, 2, false, " ", "pads when starting in middle of double-width character"},
      {"你好", 3, 3, false, " ", "pads when ending in middle of double-width character"},
      {"你好世界", 2, 4, false, " 好", "pads start and includes full character"},
      {"你好世界", 3, 5, false, "好 ", "includes full character and pads end"},
      {"你好世界", 2, 5, false, " 好 ", "pads both start and end of double-width characters"},

      -- No padding tests (no_pad = true)
      {"你好", 2, 2, true, "", "no padding when starting in middle of double-width character"},
      {"你好", 3, 3, true, "", "no padding when ending in middle of double-width character"},
      {"你好世界", 2, 4, true, "好", "no padding start, includes full character"},
      {"你好世界", 3, 5, true, "好", "includes full character, no padding end"},
      {"你好世界", 2, 5, true, "好", "no padding both start and end, includes full character"},

      -- Edge cases
      {"", 1, 1, false, "", "handles empty string"},
      {"a", 1, math.huge, false, "a", "handles j = math.huge"},
      {"你好", 1, math.huge, false, "你好", "handles j = math.huge with double-width characters"},
      {"a你b", 1, math.huge, false, "a你b", "handles j = math.huge with mixed characters"},

      -- Complex mixed character tests
      {"Hello 世界 🌍", 1, 10, false, "Hello 世界", "extracts from complex mixed string"},
      {"Hello 世界 🌍", 7, 10, false, "世界", "extracts double-width characters from complex string"},
      {"Hello 世界 🌍", 8, 8, false, " ", "pads when in middle of double-width character in complex string"},
      {"Hello 世界 🌍", 8, 8, true, "", "no padding when in middle of double-width character in complex string"},
    }

    for _, test_case in ipairs(test_cases) do
      local input = test_case[1]
      local i = test_case[2]
      local j = test_case[3]
      local no_pad = test_case[4]
      local expected = test_case[5]
      local description = test_case[6]
      it(description, function()
        local result = utils.utf8sub_col(input, i, j, no_pad)
        assert.are.equal(expected, result)
      end)
    end
  end

  -- Test error conditions
  it("throws error for negative starting column", function()
    assert.has_error(function()
      utils.utf8sub_col("hello", -1, 5)
    end, "Starting column must be positive")
  end)


  it("throws error for negative ending column", function()
    assert.has_error(function()
      utils.utf8sub_col("hello", 1, -1)
    end, "Ending column must be positive")
  end)


  it("throws error for zero starting column", function()
    assert.has_error(function()
      utils.utf8sub_col("hello", 0, 5)
    end, "Starting column must be positive")
  end)


  it("throws error for zero ending column", function()
    assert.has_error(function()
      utils.utf8sub_col("hello", 1, 0)
    end, "Ending column must be positive")
  end)

end)
