-- Integration tests for content_indent feature.
-- When content_indent is enabled, child lists align to the parent's content
-- column (marker width) instead of using tabstop.

local auto = require("autolist.auto")
local config = require("autolist.config")

-- Helper: set buffer with content_indent enabled, then recalculate.
local function recalc_content_indent(lines, cursor_line)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.bo.filetype = "markdown"
  vim.opt.expandtab = true
  vim.opt.tabstop = 2  -- deliberately small to show the difference
  config.update({ content_indent = true })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { cursor_line or 1, 0 })

  auto.recalculate()

  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

describe("recalculate (content_indent)", function()
  after_each(function()
    config.update({ content_indent = false })
  end)

  it("detects child list at 3-space indent for '1. ' parent", function()
    local result = recalc_content_indent({
      "1. parent",
      "   5. child a",
      "   8. child b",
      "2. second parent",
    }, 1)

    assert.are.equal("1. parent",         result[1])
    assert.are.equal("   1. child a",     result[2])
    assert.are.equal("   2. child b",     result[3])
    assert.are.equal("2. second parent",  result[4])
  end)

  it("renumbers children under unordered parent at 2-space indent", function()
    local result = recalc_content_indent({
      "1. parent",
      "   - child a",
      "   - child b",
      "1. second parent",
    }, 1)

    assert.are.equal("1. parent",         result[1])
    assert.are.equal("   - child a",      result[2])
    assert.are.equal("   - child b",      result[3])
    assert.are.equal("2. second parent",  result[4])
  end)

  it("detects child list at 2-space indent for '- ' parent", function()
    local result = recalc_content_indent({
      "- parent",
      "  1. child a",
      "  1. child b",
    }, 1)

    -- Unordered parent won't be renumbered, but children should be
    assert.are.equal("- parent",        result[1])
    assert.are.equal("  1. child a",    result[2])
    assert.are.equal("  2. child b",    result[3])
  end)

  it("handles nested content-aligned indentation (3 levels)", function()
    local result = recalc_content_indent({
      "1. top",
      "   1. mid",
      "      1. deep",
      "      1. deep2",
    }, 1)

    assert.are.equal("1. top",           result[1])
    assert.are.equal("   1. mid",        result[2])
    assert.are.equal("      1. deep",    result[3])
    assert.are.equal("      2. deep2",   result[4])
  end)

  it("does not match child at wrong indent", function()
    -- With "1. " parent (content_width=3), a 2-space indent should NOT
    -- be treated as a child list — it should terminate recalculation.
    local result = recalc_content_indent({
      "1. parent",
      "  1. not a child",
    }, 1)

    assert.are.equal("1. parent",        result[1])
    assert.are.equal("  1. not a child", result[2])  -- unchanged
  end)

  it("still renumbers flat lists normally", function()
    local result = recalc_content_indent({
      "1. first",
      "1. second",
      "1. third",
    }, 1)

    assert.are.equal("1. first",  result[1])
    assert.are.equal("2. second", result[2])
    assert.are.equal("3. third",  result[3])
  end)
end)

describe("find_parent_line (content_indent)", function()
  local utils = require("autolist.utils")
  local list_types = { "[-+*]", "%d+[.)]", "%a[.)]", "%u+[.)]" }

  local function setup_buf(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo.filetype = "markdown"
    vim.opt.expandtab = true
    vim.opt.tabstop = 3
    config.update({ content_indent = true })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  after_each(function()
    config.update({ content_indent = false })
  end)

  it("walks past siblings to find parent", function()
    setup_buf({
      "1. parent",
      "   a) child a",
      "      - grandchild 1",
      "      - grandchild 2",
    })

    local ln, line = utils.find_parent_line(4, list_types)
    assert.are.equal(2, ln)
    assert.are.equal("   a) child a", line)
  end)

  it("returns nil when no parent exists above top-level siblings", function()
    setup_buf({
      "1. first",
      "2. second",
      "3. third",
    })

    local ln = utils.find_parent_line(3, list_types)
    assert.is_nil(ln)
  end)
end)

describe("shift-tab dedent (content_indent)", function()
  after_each(function()
    config.update({ content_indent = false })
  end)

  -- Simulates shift-tab by manually dedenting + recalculating synchronously
  -- (the real shift_tab() uses an async timer for recalculate).
  local function simulate_shift_tab(lines, cursor_line)
    local utils = require("autolist.utils")
    local list_types = { "[-+*]", "%d+[.)]", "%a[.)]", "%u+[.)]" }

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo.filetype = "markdown"
    vim.opt.expandtab = true
    vim.opt.tabstop = 3
    config.update({ content_indent = true })

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { cursor_line, 0 })

    -- Reproduce the shift-tab logic from handle_indent()
    local cur_line = vim.fn.getline(".")
    local content = cur_line:gsub("^%s*", "", 1)
    local _, parent = utils.find_parent_line(cursor_line, list_types)
    if parent then
      local target = utils.get_indent_lvl(parent)
      vim.fn.setline(cursor_line, string.rep(" ", target) .. content)
    else
      vim.fn.setline(cursor_line, content)
    end

    auto.recalculate()

    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  it("dedents nested bullet to sibling of parent lettered list", function()
    local result = simulate_shift_tab({
      "1. Calculate residual variance",
      "   - Number of observations note",
      "2. Calculate the critical value",
      "3. For each substantive parameter:",
      "   a) Increment slightly upward",
      "      - May want to use standard errors",
      "      - cursor is here",
    }, 7)

    assert.are.equal("   b) cursor is here", result[7])
  end)

  it("dedents to top level when already at first child level", function()
    local result = simulate_shift_tab({
      "1. parent",
      "   a) child",
      "   b) another child",
    }, 3)

    assert.are.equal("2. another child", result[3])
  end)
end)
