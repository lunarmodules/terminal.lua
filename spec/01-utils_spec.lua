describe("Utils", function()

  local utils

  before_each(function()
    utils = require "terminal.utils"
  end)



  describe("invalid_constant()", function()

    it("handles numbers only table", function()
      local c = {
        "one", "two", "three"
      }
      local result = utils.invalid_constant(4, c)
      assert.are.equal('Invalid value: 4. Expected one of: 1, 2, 3', result)
    end)


    it("handles strings only table", function()
      local c = {
        one = 1, two = 2, three = 3
      }
      local result = utils.invalid_constant("four", c)
      assert.are.equal('Invalid value: "four". Expected one of: "one", "three", "two"', result)
    end)


    it("handles mixed table", function()
      local c = {
        1, 2, three = 3, four = 4
      }
      local result = utils.invalid_constant(5, c)
      assert.are.equal('Invalid value: 5. Expected one of: 1, 2, "four", "three"', result)
    end)


    it("uses the prefix if given", function()
      local c = {
        "one", "two", "three"
      }
      local result = utils.invalid_constant(4, c, "Invalid something: ")
      assert.are.equal('Invalid something: 4. Expected one of: 1, 2, 3', result)
    end)

  end)



  describe("throw_invalid_constant()", function()

    it("throws an error", function()
      local c = {
        "one", "two", "three"
      }
      local f = function()
        utils.throw_invalid_constant(4, c)
      end
      assert.has_error(f, 'Invalid value: 4. Expected one of: 1, 2, 3')
    end)

  end)



  describe("make_lookup()", function()

    it("creates a lookup table throwing errors", function()
      local const = utils.make_lookup("foreground color", {
        red = 1, green = 2, blue = 3
      })
      assert.are.equal(1, const.red)
      assert.are.equal(2, const.green)
      assert.are.equal(3, const.blue)
      local f = function()
        return const.yellow
      end
      assert.has_error(f, 'Invalid foreground color: "yellow". Expected one of: "blue", "green", "red"')
    end)

  end)



  describe("resolve_index()", function()

    local list = {
      { i = 3,  max = 5, min = 2,   exp = 3, desc = "proper range remains unchanged" },
      { i = 0,  max = 5, min = 2,   exp = 2, desc = "zero is clamped to min" },
      { i = -1, max = 5, min = 2,   exp = 5, desc = "negative index is clamped to max" },
      { i = -2, max = 5, min = 2,   exp = 4, desc = "negative index is resolved" },
      { i = -6, max = 5, min = 2,   exp = 2, desc = "negative index is clamped to min" },
      { i = 0,  max = 5, min = nil, exp = 1, desc = "minimum defaults to 1" },
    }

    for _, v in ipairs(list) do
      it(v.desc, function()
        assert.are.equal(v.exp, utils.resolve_index(v.i, v.max, v.min))
      end)
    end

  end)



  describe("class", function()

    it("creates a class", function()
      local MyClass = utils.class()
      assert.is_not_nil(MyClass)
      assert.is_not_nil(MyClass.__index)
      assert.is_not_nil(MyClass.__index.__index)
    end)


    it("instantiation calls the 'init' method", function()
      local MyClass = utils.class()
      function MyClass:init()
        self.value = 42
      end
      local instance = MyClass()
      assert.is_not_nil(instance)
      assert.are.equal(instance.super, MyClass)
      assert.are.equal(42, instance.value)
    end)


    it("subclassing works", function()
      local Cat = utils.class()
      function Cat:init()
        self.value = 42
      end

      local Lion = utils.class(Cat)
      function Lion:init()
        Cat.init(self)
        self.value = self.value * 2
      end

      local instance = Lion()
      assert.is_not_nil(instance)
      assert.are.equal(Lion.super, Cat)
      assert.are.equal(84, instance.value)
    end)


    it("instantiating calls initializer with parameters", function()
      local Cat = utils.class()
      function Cat:init(value)
        self.value = value or 42
      end

      local Lion = utils.class(Cat)
      function Lion:init(...)
        Cat.init(self, ...)  -- call ancenstor initializer
        self.value = self.value * 2
      end

      local instance = Lion(10)
      assert.is_not_nil(instance)
      assert.are.equal(instance.super, Lion)
      assert.are.equal(20, instance.value)
    end)


    it("calling 'init' on an instance throws an error", function()
      local Cat = utils.class()
      function Cat:init(value)
        self.value = value or 42
      end

      local Lion = utils.class(Cat)
      function Lion:init(...)
        Cat.init(self, ...)  -- call ancenstor initializer
        self.value = self.value * 2
      end

      local instance = Lion(10)
      local f = function()
        instance:init(20)
      end
      assert.has_error(f, "the 'init' method should never be called directly")
    end)


    it("instantiating an instance of a class throws an error", function()
      local MyClass = utils.class()
      local myInstance = MyClass()
      local f = function()
        myInstance()
      end
      assert.has_error(f, "Constructor can only be called on a Class")
    end)


    it("subclassing an instance throws an error", function()
      local MyClass = utils.class()
      local myInstance = MyClass()
      local f = function()
        utils.class(myInstance)
      end
      assert.has_error(f, "Baseclass is not a Class, can only subclass a Class")
    end)

  end)



  describe("strip_ansi()", function()

    it("returns empty string unchanged", function()
      assert.are.equal("", utils.strip_ansi(""))
    end)


    it("errors on nil", function()
      assert.has_error(function()
        utils.strip_ansi(nil)
      end)
    end)


    it("returns plain text unchanged", function()
      assert.are.equal("plain", utils.strip_ansi("plain"))
      assert.are.equal("hello world", utils.strip_ansi("hello world"))
    end)


    it("strips SGR (color/attribute) sequences", function()
      local red = "\27[31m"
      local reset = "\27[0m"
      assert.are.equal("red", utils.strip_ansi(red .. "red" .. reset))
      assert.are.equal("bold", utils.strip_ansi("\27[1mbold\27[0m"))
    end)


    it("strips CSI cursor/control sequences", function()
      assert.are.equal("", utils.strip_ansi("\27[2J\27[H"))
      assert.are.equal("x", utils.strip_ansi("\27[10;20Hx\27[6n"))
      assert.are.equal("ab", utils.strip_ansi("a\27[1Kb"))
    end)


    it("strips OSC sequences (until BEL or ST)", function()
      assert.are.equal("", utils.strip_ansi("\27]0;title\7"))
      assert.are.equal("xy", utils.strip_ansi("x\27]1;http://example.com\27\\y"))
      assert.are.equal("y", utils.strip_ansi("\27]1;url\27\\y"))
    end)


    it("strips C1 CSI (0x9b)", function()
      -- 0x9b is C1 CSI (same as ESC [); following bytes are params + final, e.g. "31m"
      assert.are.equal("x", utils.strip_ansi("\15531mx"))
    end)


    it("strips mixed content", function()
      local s = "\27[1m\27[31mbold red\27[0m and \27[32mgreen\27[0m"
      assert.are.equal("bold red and green", utils.strip_ansi(s))
    end)

  end)

end)
