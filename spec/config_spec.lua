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

    it("has loose_lists disabled by default", function()
      assert.is_false(config.loose_lists)
    end)

    it("has content_indent enabled by default", function()
      assert.is_true(config.content_indent)
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

    it("can enable loose_lists", function()
      config.update({ loose_lists = true })
      assert.is_true(config.loose_lists)
    end)

    it("can enable content_indent", function()
      config.update({ content_indent = true })
      assert.is_true(config.content_indent)
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

  describe("buffer-aware accessors", function()
    local saved_tabstop, saved_expandtab

    before_each(function()
      config.update()
      saved_tabstop = vim.bo.tabstop
      saved_expandtab = vim.bo.expandtab
    end)

    after_each(function()
      vim.bo.tabstop = saved_tabstop
      vim.bo.expandtab = saved_expandtab
      vim.b.autolist_content_indent = nil
    end)

    it("indent_width follows buffer-local tabstop with expandtab", function()
      vim.bo.expandtab = true
      vim.bo.tabstop = 4
      assert.are.equal(4, config.indent_width())
      vim.bo.tabstop = 2
      assert.are.equal(2, config.indent_width())
    end)

    it("indent_width is 1 without expandtab", function()
      vim.bo.expandtab = false
      assert.are.equal(1, config.indent_width())
    end)

    it("indent_string matches the buffer indent settings", function()
      vim.bo.expandtab = true
      vim.bo.tabstop = 3
      assert.are.equal("   ", config.indent_string())
      vim.bo.expandtab = false
      assert.are.equal("\t", config.indent_string())
    end)

    it("content_indent_enabled follows the global setting", function()
      config.update({ content_indent = true })
      assert.is_true(config.content_indent_enabled())
      config.update({ content_indent = false })
      assert.is_false(config.content_indent_enabled())
    end)

    it("b:autolist_content_indent overrides the global setting", function()
      config.update({ content_indent = true })
      vim.b.autolist_content_indent = false
      assert.is_false(config.content_indent_enabled())

      config.update({ content_indent = false })
      vim.b.autolist_content_indent = true
      assert.is_true(config.content_indent_enabled())
    end)
  end)
end)
