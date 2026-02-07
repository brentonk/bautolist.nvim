local config = require("autolist.config")

describe("config", function()
  describe("defaults", function()
    before_each(function()
      config.update()
    end)

    it("is enabled by default", function()
      assert.is_true(config.enabled)
    end)

    it("has colon settings", function()
      assert.is_true(config.colon.indent)
      assert.is_true(config.colon.indent_raw)
      assert.are.equal("-", config.colon.preferred)
    end)

    it("has cycle list", function()
      assert.are.equal(6, #config.cycle)
      assert.are.equal("-", config.cycle[1])
    end)

    it("has markdown file type lists", function()
      assert.is_table(config.lists.markdown)
      assert.is_true(#config.lists.markdown > 0)
    end)

    it("has checkbox config", function()
      assert.are.equal("%[", config.checkbox.left)
      assert.are.equal("%]", config.checkbox.right)
      assert.are.equal("x", config.checkbox.fill)
    end)

    it("sets list_cap", function()
      assert.are.equal(50, config.list_cap)
    end)

    it("sets tab based on expandtab", function()
      assert.is_not_nil(config.tab)
      assert.is_not_nil(config.tabstop)
    end)
  end)

  describe("update", function()
    it("merges user options", function()
      config.update({ colon = { preferred = "*" } })
      assert.are.equal("*", config.colon.preferred)
      -- other defaults preserved
      assert.is_true(config.colon.indent)
    end)

    it("does nothing when enabled is false", function()
      local old_cycle = config.cycle
      config.update({ enabled = false })
      -- cycle should not have been updated (update returns early)
      assert.are.equal(old_cycle, config.cycle)
    end)

    it("adds custom filetypes to lists", function()
      config.update({
        lists = {
          org = { "[-+*]" },
        },
      })
      assert.is_table(config.lists.org)
      assert.are.equal("[-+*]", config.lists.org[1])
    end)
  end)
end)
