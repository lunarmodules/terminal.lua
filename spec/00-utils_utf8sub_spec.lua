describe("utils.utf8sub()", function()

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
      {"hello", 1, 5, "hello", "extracts full ASCII string"},
      {"hello", 2, 4, "ell", "extracts middle of ASCII string"},
      {"hello", 1, 3, "hel", "extracts start of ASCII string"},
      {"hello", 3, 5, "llo", "extracts end of ASCII string"},
      {"hello", 1, 1, "h", "extracts single character from ASCII"},
      {"hello", 6, 10, "", "returns empty string when start beyond string"},
      {"hello", 3, 2, "", "returns empty string when j < i"},
      {"hello", 1, -1, "hello", "extracts from start to end with negative j"},
      {"hello", -3, -1, "llo", "extracts from negative start to negative end"},
      {"hello", 2, -2, "ell", "extracts from positive start to negative end"},

      -- UTF-8 single-width character tests
      {"héllo", 1, 5, "héllo", "extracts full UTF-8 string with single-width chars"},
      {"héllo", 2, 4, "éll", "extracts middle of UTF-8 string"},
      {"café", 1, 4, "café", "extracts full UTF-8 string ending with accent"},
      {"café", 2, 3, "af", "extracts middle of UTF-8 string with accent"},
      {"café", 4, 4, "é", "extracts single UTF-8 character with accent"},

      -- UTF-8 double-width character tests
      {"你好", 1, 2, "你好", "extracts full double-width UTF-8 string"},
      {"你好", 1, 1, "你", "extracts first double-width character"},
      {"你好", 2, 2, "好", "extracts second double-width character"},
      {"你好世界", 2, 3, "好世", "extracts middle double-width characters"},
      {"你好世界", 1, 4, "你好世界", "extracts all double-width characters"},
      {"你好世界", 3, 4, "世界", "extracts last two double-width characters"},

      -- Mixed single and double-width character tests
      {"a你b好c", 1, 5, "a你b好c", "extracts mixed single and double-width characters"},
      {"a你b好c", 2, 4, "你b好", "extracts mixed characters from middle"},
      {"a你b好c", 1, 3, "a你b", "extracts mixed characters from start"},
      {"a你b好c", 3, 5, "b好c", "extracts mixed characters from end"},
      {"a你b好c", 2, 2, "你", "extracts single double-width character"},
      {"a你b好c", 4, 4, "好", "extracts single double-width character from middle"},

      -- Edge cases
      {"", 1, 1, "", "handles empty string"},
      {"a", 1, 1, "a", "handles single character"},
      {"你好", 1, 2, "你好", "handles two double-width characters"},
      {"a你b", 1, 3, "a你b", "handles mixed characters"},
      {"a你b", 2, 2, "你", "extracts single double-width character from mixed string"},

      -- Complex mixed character tests
      {"Hello 世界 🌍", 1, 9, "Hello 世界 ", "extracts from complex mixed string"},
      {"Hello 世界 🌍", 7, 8, "世界", "extracts double-width characters from complex string"},
      {"Hello 世界 🌍", 6, 6, " ", "extracts space character"},
      {"Hello 世界 🌍", 9, 9, " ", "extracts emoji character (may display as space)"},
      {"Hello 世界 🌍", 1, 5, "Hello", "extracts ASCII part"},
      {"Hello 世界 🌍", 7, 9, "世界 ", "extracts non-ASCII part"},

      -- Negative indexing tests
      {"hello", 1, -1, "hello", "extracts all with negative end"},
      {"hello", 2, -2, "ell", "extracts middle with negative end"},
      {"你好", 1, -1, "你好", "extracts all double-width with negative end"},
      {"你好", 2, -1, "好", "extracts last double-width with negative end"},
      {"a你b好c", 2, -2, "你b好", "extracts mixed characters with negative end"},

      -- Edge cases
      {"", 1, 5, "", "handles empty string"},
      {"hello", 0, 3, "hel", "handles zero start index (wraps to last character)"},
      {"hello", 1, 0, "", "handles zero end index"},
      {"hello", 10, 15, "", "handles start beyond string length"},
      {"hello", 1, 15, "hello", "handles end beyond string length"},
      {"hello", -10, -1, "hello", "handles negative start beyond string length (wraps around)"},
      {"hello", 1, -10, "", "handles negative end beyond string length"},
    }

    for _, test_case in ipairs(test_cases) do
      local input = test_case[1]
      local i = test_case[2]
      local j = test_case[3]
      local expected = test_case[4]
      local description = test_case[5]
      it(description, function()
        local result = utils.utf8sub(input, i, j)
        assert.are.equal(expected, result)
      end)
    end
  end

  -- Test error conditions
  it("handles nil input gracefully", function()
    local success, err = pcall(function()
      return utils.utf8sub(nil, 1, 5)
    end)
    assert.is_false(success)
    assert.matches("bad argument #1 to 'len'", err)
  end)

end)
