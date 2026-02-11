describe("utils.truncate_ellipsis()", function()

  local utils
  local text

  before_each(function()
    utils = require("terminal.utils")
    text = require("terminal.text")
  end)


  after_each(function()
    utils = nil
    text = nil
  end)


  do
    local test_cases = {
      -- Basic functionality
      { 10, nil,                          nil,   "",                0,  "returns empty string and width 0 for nil text"},
      { 10, "",                           nil,   "",                0,  "returns empty string and width 0 for empty string"},
      { 20, "Hello World",                nil,   "Hello World",    11,  "returns full text when width is sufficient"},
      {  5, "Hello",                      nil,   "Hello",           5,  "returns full text when width exactly matches"},
      { 10, "Hi",                         nil,   "Hi",              2,  "handles very short text that fits"},

      -- Right truncation (default)
      { 15, "Very Long Text That Needs Truncation", nil,   "Very Long Text…",      15, "truncates from right with ellipsis (default)"},
      { 15, "Very Long Text That Needs Truncation", "right", "Very Long Text…",    15, "truncates from right with ellipsis (explicit)"},
      {  4, "ABCDEF",                     "right", "ABC…",          4,  "handles width of exactly 4 (minimum for ellipsis) right"},
      {  1, "Hello",                      "right", "",              0,  "drops text when width less than or equal to ellipsis width right"},
      {  0, "Hello",                      "right", "",              0,  "drops text when width is 0 right"},
      {  5, "A",                          "right", "A",             1,  "handles single character text"},
      {  4, "Test",                       "right", "Test",          4,  "handles text exactly at truncation boundary right"},

      -- Left truncation
      { 15, "Very Long Text That Needs Truncation", "left",  "…eds Truncation",    15, "truncates from left with ellipsis"},
      {  4, "ABCDEF",                     "left",  "…DEF",          4,  "handles width of exactly 4 (minimum for ellipsis) left"},
      {  1, "Hello",                      "left",  "",              0,  "drops text when width less than or equal to ellipsis width left"},

      -- Drop truncation
      {  5, "Very Long Text",             "drop",  "",              0,  "returns empty string when text is too long"},
      {  3, "Hello",                      "drop",  "",              0,  "returns empty string when width less than 4 drop"},
      { 10, "Hi",                         "drop",  "Hi",            2,  "returns full text when it fits drop"},

      -- Default truncation type behavior
      { 10, "Very Long Text",             nil,     "Very Long…",    10, "defaults to right truncation when type is nil"},
      { 20, "Short",                      "right", "Short",         5,  "handles width larger than text right"},
      { 20, "Short",                      "left",  "Short",         5,  "handles width larger than text left"},
      { 20, "Short",                      "drop",  "Short",         5,  "handles width larger than text drop"},

      -- UTF-8 handling
      { 10, "你好世界",                   "right", "你好世界",      8,  "handles UTF-8 double-width characters right (full text fits)"},
      {  7, "你好世界",                   "right", "你好世…",       7,  "handles UTF-8 double-width characters right (truncated)"},
      { 10, "Hello 世界",                 "right", "Hello 世界",   10,  "handles mixed ASCII and UTF-8 right (full text)"},
      {  8, "Hello 世界",                 "right", "Hello …",      7,  "handles mixed ASCII and UTF-8 right (truncated width 8)"},
      {  7, "Hello 世界",                 "right", "Hello …",       7,  "handles mixed ASCII and UTF-8 right (truncated width 7)"},
      { 10, "你好世界",                   "left",  "你好世界",      8,  "handles UTF-8 double-width characters left (full text fits)"},
      {  7, "你好世界",                   "left",  "…好世界",         7,  "handles UTF-8 double-width characters left (truncated)"},
      { 10, "Hello 世界",                 "left",  "Hello 世界",   10,  "handles mixed ASCII and UTF-8 left (full text)"},
      {  8, "Hello 世界",                 "left",  "…lo 世界",        8,  "handles mixed ASCII and UTF-8 left (truncated width 8)"},
      {  7, "Hello 世界",                 "left",  "…o 世界",         7,  "handles mixed ASCII and UTF-8 left (truncated width 7)"},

      -- Edge cases
      { 10, "     ",                      nil,     "     ",         5,  "handles text with only spaces"},
      {  2, "Hi",                         nil,     "Hi",            2,  "handles very short text that exactly fits"},
    }

    for _, test_case in ipairs(test_cases) do
      local width = test_case[1]
      local input_text = test_case[2]
      local trunc_type = test_case[3]
      local expected_str = test_case[4]
      local expected_width = test_case[5]
      local description = test_case[6]

      it(description, function()
        local str, w = utils.truncate_ellipsis(width, input_text, trunc_type)
        assert.are.equal(expected_str, str)
        assert.are.equal(expected_width, w)
        -- Verify that the reported width matches the actual width of the returned string
        local actual_width = text.width.utf8swidth(str)
        assert.are.equal(actual_width, w)
      end)
    end
  end


  describe("custom ellipsis", function()

    do
      local test_cases = {
        -- Custom ellipsis strings
        { 10, "Very Long Text",  "right", "...",  "Very Lo...",    10, "uses custom ellipsis string (three dots)"},
        { 10, "Very Long Text",  "right", "..",   "Very Lon..",    10, "uses custom ellipsis string (two dots) for right truncation"},
        { 10, "Very Long Text",  "left",  "..",   "..ong Text",    10, "uses custom ellipsis string (two dots) for left truncation"},
        { 10, "Very Long Text",  "right", ">>>",  "Very Lo>>>",    10, "handles multi-character ellipsis string"},
        {  9, "Hello 世界",      "right", "…",    "Hello 世…",      9, "handles UTF-8 single-width ellipsis character"},
        {  6, "ABCDEF",          "right", "...",  "ABCDEF",        6, "handles custom ellipsis with exact width fit"},

        -- Width vs ellipsis width edge cases
        {  2, "Hello",           "right", "...",  "",               0, "drops text when width is less than custom ellipsis width"},
        {  3, "Hello",           "right", "...",  "",               0, "drops text when width equals custom ellipsis width"},
        {  1, "Hello",           "right", nil,    "",               0, "drops text when width equals default ellipsis width"},

        -- Empty ellipsis cases
        { 10, "Very Long Text",  "right", "",     "Very Long ",    10, "uses empty ellipsis string for right truncation"},
        { 10, "Very Long Text",  "left",  "",     " Long Text",    10, "uses empty ellipsis string for left truncation"},
        {  0, "Hello",           "right", "",     "",               0, "handles empty ellipsis when width is 0"},
        {  5, "Hello",           "right", "",     "Hello",          5, "handles empty ellipsis when width equals text width"},
        {  3, "Hello",           "right", "",     "Hel",            3, "handles empty ellipsis when width is less than text width (right truncation)"},
        {  3, "Hello",           "left",  "",     "llo",            3, "handles empty ellipsis when width is less than text width (left truncation)"},
        {  5, "Hello",           "drop",  "",     "Hello",          5, "handles empty ellipsis with drop truncation type"},
        {  3, "Hello",           "drop",  "",     "",               0, "handles empty ellipsis with drop truncation type when text doesn't fit"},

        -- Empty ellipsis with UTF-8
        { 10, "你好世界",        "right", "",     "你好世界",       8, "handles empty ellipsis with UTF-8 text (full text fits)"},
        {  6, "你好世界",        "right", "",     "你好世",         6, "handles empty ellipsis with UTF-8 text (truncated right)"},
        {  6, "你好世界",        "left",  "",     "好世界",         6, "handles empty ellipsis with UTF-8 text (truncated left)"},
        {  8, "Hello 世界",      "right", "",     "Hello 世",       8, "handles empty ellipsis with mixed ASCII and UTF-8"},
      }

      for _, test_case in ipairs(test_cases) do
        local width = test_case[1]
        local input_text = test_case[2]
        local trunc_type = test_case[3]
        local ellipsis = test_case[4]
        local expected_str = test_case[5]
        local expected_width = test_case[6]
        local description = test_case[7]

        it(description, function()
          local str, w = utils.truncate_ellipsis(width, input_text, trunc_type, ellipsis)
          assert.are.equal(expected_str, str)
          assert.are.equal(expected_width, w)
          -- Verify that the reported width matches the actual width of the returned string
          if str ~= "" then
            local actual_width = text.width.utf8swidth(str)
            assert.are.equal(actual_width, w)
          end
        end)
      end
    end

  end)

end)
