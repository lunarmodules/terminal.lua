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
      local count = 0
      for _ in s:panel_set() do count = count + 1 end
      assert.are.equal(3, count)
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
      assert.are.equal("a", s:get_selected())
      assert.are.equal(a, s:get_panel("a"))
    end)


    it("auto-selects when adding to empty set", function()
      local s = Set {}
      local a = make_panel("a")
      s:add(a)
      assert.are.equal("a", s:get_selected())
      assert.is_true(a:visible())
    end)


    it("selects new panel when jump=true", function()
      local s = Set {}
      local a = make_panel("a")
      local b = make_panel("b")
      s:add(a)
      s:select("a")
      s:add(b, true)
      assert.are.equal("b", s:get_selected())
      assert.is_true(b:visible())
      assert.is_false(a:visible())
    end)


    it("preserves selection when jump=false", function()
      local s = Set {}
      local a = make_panel("a")
      local b = make_panel("b")
      s:add(a)
      s:select("a")
      s:add(b, false)
      assert.are.equal("a", s:get_selected())
      assert.is_true(a:visible())
      assert.is_false(b:visible())
    end)

  end)


  describe("select()", function()

    it("switches the visible child to the selected panel", function()
      local a = make_panel("a")
      local b = make_panel("b")
      local s = Set { children = { a, b } }
      local new
      if s:get_selected() == "a" then
        assert.is_false(b:visible())
        assert.is_true(a:visible())
        new = "b"
      else
        assert.is_false(a:visible())
        assert.is_true(b:visible())
        new = "a"
      end
      s:select(new)
      assert.are.equal(new, s:get_selected())
      if new == "b" then
        assert.is_false(a:visible())
        assert.is_true(b:visible())
      else
        assert.is_false(b:visible())
        assert.is_true(a:visible())
      end
    end)


    it("returns true on successful selection", function()
      local s = Set {}
      local a = make_panel("a")
      s:add(a)
      local success = s:select("a")
      assert.is_true(success)
    end)


    it("can select the same panel twice", function()
      local s = Set {}
      local a = make_panel("a")
      local b = make_panel("b")
      s:add(a)
      s:add(b)
      s:select("a")
      assert.are.equal("a", s:get_selected())
      assert.is_true(s:select("a"))
      assert.are.equal("a", s:get_selected())
      assert.is_true(a:visible())
      assert.is_false(b:visible())
    end)

  end)


  describe("remove()", function()

    it("removes a non-selected panel", function()
      local s = Set {}
      s:add(make_panel("a"))
      s:add(make_panel("b"))
      s:select("a")
      s:remove("b")
      assert.are.equal("a", s:get_selected())
      assert.are.same({ nil, "panel not found: b" }, {s:select("b")})
    end)


    it("removes the selected panel and selects another if available", function()
      local s = Set {}
      s:add(make_panel("a"))
      s:add(make_panel("b"))
      s:select("b")
      s:remove("b")
      assert.are.equal("a", s:get_selected())
      assert.are.equal("a", s:get_panel("a").name)
      assert.is_nil(s:get_panel("b"))
    end)


    it("handles removing the last panel (dummies remain)", function()
      local s = Set {}
      s:add(make_panel("a"))
      s:remove("a")
      assert.is_nil(s:get_selected())
      local count = 0
      for _ in s:panel_set() do count = count + 1 end
      assert.are.equal(0, count)
      assert.are.equal(2, #s.children)
      assert.is_true(s.children[1].name == "__dummy__")
      assert.is_true(s.children[2].name == "__dummy__")
    end)


    it("returns the removed panel instance", function()
      local s = Set {}
      local a = make_panel("a")
      local b = make_panel("b")
      s:add(a)
      s:add(b)
      local removed = s:remove("b")
      assert.are.equal(b, removed)
      assert.are.equal("b", removed.name)
    end)

  end)


  describe("get_selected()", function()

    it("returns nil with error message when no panel is selected", function()
      local s = Set {}
      local selected, err = s:get_selected()
      assert.is_nil(selected)
      assert.are.equal("no panel selected in set", err)
    end)


    it("returns the selected panel name when one is selected", function()
      local s = Set {}
      local a = make_panel("a")
      s:add(a)
      assert.are.equal("a", s:get_selected())
    end)


    it("returns the selected panel name when multiple panels exist", function()
      local s = Set {}
      local a = make_panel("a")
      local b = make_panel("b")
      local c = make_panel("c")
      s:add(a)
      s:add(b)
      s:add(c)
      s:select("b")
      assert.are.equal("b", s:get_selected())
    end)

  end)


  describe("panel_set()", function()

    it("iterates over all panels in the set", function()
      local s = Set {}
      local a = make_panel("a")
      local b = make_panel("b")
      local c = make_panel("c")
      s:add(a)
      s:add(b)
      s:add(c)
      local names = {}
      for p in s:panel_set() do
        names[#names + 1] = p.name
      end
      assert.are.equal(3, #names)
      assert.is_true((names[1] == "a" or names[1] == "b" or names[1] == "c"))
      assert.is_true((names[2] == "a" or names[2] == "b" or names[2] == "c"))
      assert.is_true((names[3] == "a" or names[3] == "b" or names[3] == "c"))
    end)


    it("returns nothing when set is empty", function()
      local s = Set {}
      local count = 0
      for _ in s:panel_set() do
        count = count + 1
      end
      assert.are.equal(0, count)
    end)


    it("works correctly after removals", function()
      local s = Set {}
      local a = make_panel("a")
      local b = make_panel("b")
      local c = make_panel("c")
      s:add(a)
      s:add(b)
      s:add(c)
      s:remove("b")
      local names = {}
      for p in s:panel_set() do
        names[#names + 1] = p.name
      end
      assert.are.equal(2, #names)
      assert.is_false(names[1] == "b" or names[2] == "b")
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


