local helpers = require "spec.helpers"


describe("output:", function()

  local t

  before_each(function()
    t = helpers.load()
  end)


  after_each(function()
    helpers.unload()
  end)



  describe("write()", function()

    it("writes a single string to the stream", function()
      t.output.write("hello")
      assert.equals("hello", helpers.get_output())
    end)


    it("writes multiple arguments concatenated without separator", function()
      t.output.write("a", "b", "c")
      assert.equals("abc", helpers.get_output())
    end)


    it("converts non-string arguments via tostring()", function()
      t.output.write(42, true)
      assert.equals("42true", helpers.get_output())
    end)


    it("handles nil arguments via tostring()", function()
      t.output.write(nil)
      assert.equals("nil", helpers.get_output())
    end)


    it("returns the write result on success", function()
      local ok, err, errno = t.output.write("x")
      assert.is_truthy(ok)
      assert.is_nil(err)
      assert.is_nil(errno)
    end)


    it("returns nil, error, errno on write failure", function()
      -- unload so we can inject a stream without the mock's set_stream guard
      helpers.unload()
      local output = require("terminal.output")

      local tmpf = require("pl.path").tmpname()
      local fh = assert(io.open(tmpf, "rb")) -- read-only: write will fail
      finally(function()
        fh:close()
        os.remove(tmpf)
      end)

      output.set_stream(fh)
      local ok, err, errno = output.write("test")
      assert.is_nil(ok)
      assert.is_string(err)
      assert.is_number(errno)
    end)

  end)



  describe("print()", function()

    it("writes a single argument followed by a newline", function()
      t.output.print("hello")
      assert.equals("hello\n", helpers.get_output())
    end)


    it("separates multiple arguments with tabs", function()
      t.output.print("a", "b", "c")
      assert.equals("a\tb\tc\n", helpers.get_output())
    end)


    it("converts non-string arguments via tostring()", function()
      t.output.print(42)
      assert.equals("42\n", helpers.get_output())
    end)


    it("handles nil arguments via tostring()", function()
      t.output.print(nil)
      assert.equals("nil\n", helpers.get_output())
    end)

  end)



  describe("printcl()", function()

    local eol_seq = "\27[0K"

    it("writes a single argument followed by clear-eol and a newline", function()
      t.output.printcl("hello")
      assert.equals("hello" .. eol_seq .. "\n", helpers.get_output())
    end)


    it("separates multiple arguments with tabs", function()
      t.output.printcl("a", "b", "c")
      assert.equals("a\tb\tc" .. eol_seq .. "\n", helpers.get_output())
    end)


    it("converts non-string arguments via tostring()", function()
      t.output.printcl(42)
      assert.equals("42" .. eol_seq .. "\n", helpers.get_output())
    end)


    it("handles nil arguments via tostring()", function()
      t.output.printcl(nil)
      assert.equals("nil" .. eol_seq .. "\n", helpers.get_output())
    end)

  end)

end)
