-- Integration tests for soft_return().
-- Verifies that continuation lines are indented to align with list content.

local auto = require("autolist.auto")
local config = require("autolist.config")

-- Helper: create a buffer, set lines, position cursor on given line, then
-- call soft_return().  Returns the buffer contents as a table of strings.
local function soft_return_buf(lines, cursor_line, opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.bo.filetype = "markdown"
  vim.opt.expandtab = true
  vim.opt.tabstop = opts.tabstop or 4
  config.update({
    content_indent = opts.content_indent ~= false,
  })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { cursor_line, 0 })

  auto.soft_return()

  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

describe("soft_return", function()
  after_each(function()
    config.update({ content_indent = false })
  end)

  it("indents continuation 2 spaces for unordered '- ' list", function()
    -- Simulate: user was on "- item", pressed <S-CR>, now cursor is on line 2
    -- which is empty.  soft_return should indent it to content column.
    local result = soft_return_buf({
      "- item",
      "",
    }, 2)

    assert.are.equal("- item", result[1])
    assert.are.equal("  ", result[2])
  end)

  it("indents continuation 3 spaces for '1. ' ordered list", function()
    local result = soft_return_buf({
      "1. item",
      "",
    }, 2)

    assert.are.equal("1. item", result[1])
    assert.are.equal("   ", result[2])
  end)

  it("indents continuation 4 spaces for '10. ' ordered list", function()
    local result = soft_return_buf({
      "10. item",
      "",
    }, 2)

    assert.are.equal("10. item", result[1])
    assert.are.equal("    ", result[2])
  end)

  it("indents continuation for nested list using full indent + content width", function()
    -- A child list indented 3 spaces with a "- " marker → content at column 5
    local result = soft_return_buf({
      "1. parent",
      "   - child item",
      "",
    }, 3)

    assert.are.equal("1. parent", result[1])
    assert.are.equal("   - child item", result[2])
    -- 3 (parent indent) + 2 (marker "- ") = 5 spaces
    assert.are.equal("     ", result[3])
  end)

  it("preserves trailing content on the current line", function()
    -- If the current line already has text, soft_return re-indents it
    local result = soft_return_buf({
      "- item",
      "continuation text",
    }, 2)

    assert.are.equal("- item", result[1])
    assert.are.equal("  continuation text", result[2])
  end)

  it("does nothing when previous line is not a list item", function()
    local result = soft_return_buf({
      "Just a paragraph.",
      "",
    }, 2)

    assert.are.equal("Just a paragraph.", result[1])
    assert.are.equal("", result[2])
  end)

  it("uses tabstop when content_indent is false", function()
    local result = soft_return_buf({
      "- item",
      "",
    }, 2, { content_indent = false, tabstop = 4 })

    assert.are.equal("- item", result[1])
    -- Without content_indent, falls back to tabstop (4)
    assert.are.equal("    ", result[2])
  end)

  it("indents continuation for '* ' unordered list", function()
    local result = soft_return_buf({
      "* item",
      "",
    }, 2)

    assert.are.equal("* item", result[1])
    assert.are.equal("  ", result[2])
  end)
end)
