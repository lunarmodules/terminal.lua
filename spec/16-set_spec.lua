describe("terminal.ui.panel.set", function()

  local Set
  local Panel

  setup(function()
    Set = require("terminal.ui.panel.set")
    Panel = require("terminal.ui.panel.init")
  end)

  teardown(function()
    Set = nil
    Panel = nil -- luacheck: ignore
  end)


  local function make_panel(name, opts)
    opts = opts or {}
    opts.name = name
    opts.content = function() end
    return Panel(opts)
  end


  describe("init()", function()

    it("creates an empty set with dummy children", function()
      local s = Set {}
      assert.is_nil(s:get_selected())
      assert.are.equal(2, #s.children)
    end)


    it("initializes with provided children and selects one by default", function()
      local a = make_panel("a")
      local b = make_panel("b")
      local s = Set { children = { a, b } }
      local selected = s:get_selected()
      assert.is_not_nil(selected)
      assert.is_true(selected == "a" or selected == "b")
      local names = s:get_names()
      assert.are.equal(2, #names)
      assert.is_true((names[1] == "a" and names[2] == "b") or (names[1] == "b" and names[2] == "a"))
      -- Verify panels are accessible via get_panel (they're in the tree)
      assert.are.equal(a, s:get_panel("a"))
      assert.are.equal(b, s:get_panel("b"))
    end)


    it("respects explicit initial selection", function()
      local a = make_panel("a")
      local b = make_panel("b")
      local s = Set { children = { a, b }, selected = "b" }
      assert.are.equal("b", s:get_selected())
      -- selected should be visible, other hidden
      assert.is_true(b:visible())
      assert.is_false(a:visible())
      -- Verify panels are accessible via get_panel
      assert.are.equal(a, s:get_panel("a"))
      assert.are.equal(b, s:get_panel("b"))
    end)


    it("initializes with multiple children and all are accessible", function()
      local a = make_panel("a")
      local b = make_panel("b")
      local c = make_panel("c")
      local s = Set { children = { a, b, c } }
      assert.are.equal(3, #s:get_names())
      -- All panels should be findable in the tree
      assert.are.equal(a, s:get_panel("a"))
      assert.are.equal(b, s:get_panel("b"))
      assert.are.equal(c, s:get_panel("c"))
    end)

  end)


  describe("add()", function()

    it("adds by panel instance using its name", function()
      local s = Set {}
      local a = make_panel("a")
      s:add(a)
      assert.are.same({ "a" }, s:get_names())
      assert.are.equal("a", s:get_selected())
    end)

  end)


  describe("select()", function()

    it("switches the visible child to the selected panel", function()
      local a = make_panel("a")
      local b = make_panel("b")
      local s = Set { children = { a, b } }
      assert.is_true(a:visible())
      assert.is_false(b:visible())
      s:select("b")
      assert.are.equal("b", s:get_selected())
      assert.is_true(b:visible())
      assert.is_false(a:visible())
    end)

  end)


  describe("remove()", function()

    it("removes a non-selected panel", function()
      local s = Set {}
      s:add(make_panel("a"))
      s:add(make_panel("b"))
      s:remove("b")
      local names = s:get_names()
      assert.are.equal(1, #names)
      assert.are.equal("a", names[1])
      assert.are.equal("a", s:get_selected())
    end)


    it("removes the selected panel and selects another if available", function()
      local s = Set {}
      s:add(make_panel("a"))
      s:add(make_panel("b"))
      s:select("b")
      s:remove("b")
      assert.are.equal("a", s:get_selected())
      local names = s:get_names()
      assert.are.equal(1, #names)
      assert.are.equal("a", names[1])
    end)


    it("handles removing the last panel (dummies remain)", function()
      local s = Set {}
      s:add(make_panel("a"))
      s:remove("a")
      assert.is_nil(s:get_selected())
      assert.are.equal(0, #s:get_names())
      assert.are.equal(2, #s.children)
      assert.is_true(s.children[1].name == "__dummy__")
      assert.is_true(s.children[2].name == "__dummy__")
    end)

  end)


  describe("layout integration", function()

    it("gives the full size to the selected child during layout", function()
      local s = Set {}
      local a = make_panel("a")
      local b = make_panel("b")
      s:add(a)
      s:add(b)
      s:select("a")
      s:calculate_layout(1, 1, 20, 80)
      assert.are.equal(20, a.height)
      assert.are.equal(80, a.width)
      s:select("b")
      s:calculate_layout(1, 1, 10, 30)
      assert.are.equal(10, b.height)
      assert.are.equal(30, b.width)
    end)

  end)

end)


