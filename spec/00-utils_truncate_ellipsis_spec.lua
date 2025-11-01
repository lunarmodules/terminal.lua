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
      { 15, "Very Long Text That Needs Truncation", nil,   "Very Long Te...",      15, "truncates from right with ellipsis (default)"},
      { 15, "Very Long Text That Needs Truncation", "right", "Very Long Te...",    15, "truncates from right with ellipsis (explicit)"},
      {  4, "ABCDEF",                     "right", "A...",          4,  "handles width of exactly 4 (minimum for ellipsis) right"},
      {  3, "Hello",                      "right", "",              0,  "drops text when width less than 4 right"},
      {  0, "Hello",                      "right", "",              0,  "drops text when width is 0 right"},
      {  5, "A",                          "right", "A",             1,  "handles single character text"},
      {  4, "Test",                       "right", "Test",          4,  "handles text exactly at truncation boundary right"},

      -- Left truncation
      { 15, "Very Long Text That Needs Truncation", "left",  "...s Truncation",     15, "truncates from left with ellipsis"},
      {  4, "ABCDEF",                     "left",  "...F",          4,  "handles width of exactly 4 (minimum for ellipsis) left"},
      {  3, "Hello",                      "left",  "",              0,  "drops text when width less than 4 left"},

      -- Drop truncation
      {  5, "Very Long Text",             "drop",  "",              0,  "returns empty string when text is too long"},
      {  3, "Hello",                      "drop",  "",              0,  "returns empty string when width less than 4 drop"},
      { 10, "Hi",                         "drop",  "Hi",            2,  "returns full text when it fits drop"},

      -- Default truncation type behavior
      { 10, "Very Long Text",             nil,     "Very Lo...",   10, "defaults to right truncation when type is nil"},
      { 20, "Short",                      "right", "Short",         5,  "handles width larger than text right"},
      { 20, "Short",                      "left",  "Short",         5,  "handles width larger than text left"},
      { 20, "Short",                      "drop",  "Short",         5,  "handles width larger than text drop"},

      -- UTF-8 handling
      { 10, "你好世界",                   "right", "你好世界",      8,  "handles UTF-8 double-width characters right (full text fits)"},
      {  7, "你好世界",                   "right", "你好...",       7,  "handles UTF-8 double-width characters right (truncated)"},
      { 10, "Hello 世界",                 "right", "Hello 世界",   10,  "handles mixed ASCII and UTF-8 right (full text)"},
      {  8, "Hello 世界",                 "right", "Hello...",      8,  "handles mixed ASCII and UTF-8 right (truncated width 8)"},
      {  7, "Hello 世界",                 "right", "Hell...",       7,  "handles mixed ASCII and UTF-8 right (truncated width 7)"},
      { 10, "你好世界",                   "left",  "你好世界",      8,  "handles UTF-8 double-width characters left (full text fits)"},
      {  7, "你好世界",                   "left",  "...世界",       7,  "handles UTF-8 double-width characters left (truncated)"},
      { 10, "Hello 世界",                 "left",  "Hello 世界",   10,  "handles mixed ASCII and UTF-8 left (full text)"},
      {  8, "Hello 世界",                 "left",  "... 世界",      8,  "handles mixed ASCII and UTF-8 left (truncated width 8)"},
      {  7, "Hello 世界",                 "left",  "...世界",       7,  "handles mixed ASCII and UTF-8 left (truncated width 7)"},

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

end)
