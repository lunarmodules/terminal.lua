describe("Sequence", function()

  local Sequence

  before_each(function()
    Sequence = require "terminal.sequence"
  end)



  it("calling creates a sequence", function()
    local s = Sequence("hello", " ", "world")
    assert.are.same({"hello", " ", "world", n = 3}, s)
  end)


  it("tostring concatenates members", function()
    local s = Sequence("hello", " ", "world")
    assert.are.equal("hello world", tostring(s))
  end)


  it("calls functions when tostring'ing", function()
    local s = Sequence("foo", function() return "---" end, "bar")
    assert.are.equal("foo---bar", tostring(s))
  end)


  it("concatenates sequences", function()
    local s1 = Sequence("hello", " ", "world")
    local s2 = Sequence("foo", function() return "---" end, "bar")
    local s3 = s1 + s2
    assert.are.same({"hello", " ", "world", "foo", s2[2], "bar", n = 6}, s3)
  end)


  it("contains no n field when empty", function()
    local s = Sequence()
    assert.is_nil(s.n)
  end)


  it("nested sequences", function()
    local s1 = Sequence("hello", " ", "world")
    local s2 = Sequence("foo", function() return "---" end, "bar")
    local s3 = Sequence(s1, " ", s2)
    assert.are.equal("hello world foo---bar", tostring(s3))
  end)


  it("adding non-seqences appends them", function()
    local s1 = Sequence("hello", " ", "world")
    local s2 = s1 + "foo"
    assert.are.equal("hello worldfoo", tostring(s2))
  end)


  it("sequences are nil safe", function()
    local s1 = Sequence(nil, nil, nil)
    local s2 = Sequence(nil, nil, nil)
    local s3 = s1 + s2
    assert.are.same({ n = 3 }, s1)
    assert.are.same({ n = 3 }, s2)
    assert.are.same({ n = 6 }, s3)
    assert.are.equal("nilnilnil", tostring(s1))
    assert.are.equal("nilnilnil", tostring(s2))
    assert.are.equal("nilnilnilnilnilnil", tostring(s3))
  end)

end)
