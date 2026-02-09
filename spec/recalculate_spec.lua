-- Integration tests for recalculate() using real Neovim buffers.
-- These tests exercise the fix for gaoDean/autolist.nvim#82:
-- indented ordered child lists must reset to 1.

local auto = require("autolist.auto")
local config = require("autolist.config")

-- Helper: set buffer lines (1-indexed), set filetype, position cursor, then
-- call recalculate().  Returns the buffer contents as a table of strings.
local function recalc_buf(lines, cursor_line)
  -- Create a scratch buffer so we don't pollute state between tests.
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.bo.filetype = "markdown"
  vim.opt.expandtab = true
  vim.opt.tabstop = 4
  config.update()

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { cursor_line or 1, 0 })

  auto.recalculate()

  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

-- One level of indentation matching config.tabstop after recalc_buf sets it.
local INDENT = "    "
local INDENT2 = "        "

describe("recalculate", function()
  it("renumbers a flat ordered list sequentially", function()
    local result = recalc_buf({
      "1. first",
      "1. second",
      "1. third",
    }, 1)

    assert.are.equal("1. first",  result[1])
    assert.are.equal("2. second", result[2])
    assert.are.equal("3. third",  result[3])
  end)

  it("resets an indented child list to 1 (#82)", function()
    local result = recalc_buf({
      "1. parent",
      INDENT .. "3. child",
      INDENT .. "4. child two",
    }, 1)

    assert.are.equal("1. parent",              result[1])
    assert.are.equal(INDENT .. "1. child",     result[2])
    assert.are.equal(INDENT .. "2. child two", result[3])
  end)

  it("renumbers child list items sequentially after reset", function()
    local result = recalc_buf({
      "1. parent",
      INDENT .. "5. alpha",
      INDENT .. "8. beta",
      INDENT .. "2. gamma",
      "2. next parent",
    }, 1)

    assert.are.equal(INDENT .. "1. alpha", result[2])
    assert.are.equal(INDENT .. "2. beta",  result[3])
    assert.are.equal(INDENT .. "3. gamma", result[4])
    assert.are.equal("2. next parent",     result[5])
  end)

  it("handles doubly-nested (3-level) lists", function()
    local result = recalc_buf({
      "1. top",
      INDENT .. "5. mid",
      INDENT2 .. "9. deep",
      INDENT2 .. "9. deep2",
    }, 1)

    assert.are.equal("1. top",            result[1])
    assert.are.equal(INDENT .. "1. mid",  result[2])
    assert.are.equal(INDENT2 .. "1. deep",  result[3])
    assert.are.equal(INDENT2 .. "2. deep2", result[4])
  end)

  it("resets alphabetic ordered child lists to a)", function()
    local result = recalc_buf({
      "1. parent",
      INDENT .. "c) child",
      INDENT .. "d) child two",
    }, 1)

    assert.are.equal("1. parent",              result[1])
    assert.are.equal(INDENT .. "a) child",     result[2])
    assert.are.equal(INDENT .. "b) child two", result[3])
  end)

  it("does not alter unordered child lists", function()
    local result = recalc_buf({
      "1. parent",
      INDENT .. "- child one",
      INDENT .. "- child two",
      "1. second parent",
    }, 1)

    assert.are.equal("1. parent",             result[1])
    assert.are.equal(INDENT .. "- child one", result[2])
    assert.are.equal(INDENT .. "- child two", result[3])
    assert.are.equal("2. second parent",      result[4])
  end)
end)

-- Helper for loose-list tests: enables loose_lists before recalculating.
local function recalc_buf_loose(lines, cursor_line)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.bo.filetype = "markdown"
  vim.opt.expandtab = true
  vim.opt.tabstop = 4
  config.update({ loose_lists = true })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { cursor_line or 1, 0 })

  auto.recalculate()

  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

describe("recalculate (loose lists)", function()
  after_each(function()
    -- reset to default (tight) after each test
    config.update({ loose_lists = false })
  end)

  it("renumbers a flat loose list", function()
    local result = recalc_buf_loose({
      "1. first",
      "",
      "1. second",
      "",
      "1. third",
    }, 1)

    assert.are.equal("1. first",  result[1])
    assert.are.equal("",          result[2])
    assert.are.equal("2. second", result[3])
    assert.are.equal("",          result[4])
    assert.are.equal("3. third",  result[5])
  end)

  it("stops at two consecutive blank lines", function()
    local result = recalc_buf_loose({
      "1. first",
      "",
      "1. second",
      "",
      "",
      "1. separate",
    }, 1)

    assert.are.equal("1. first",    result[1])
    assert.are.equal("",            result[2])
    assert.are.equal("2. second",   result[3])
    assert.are.equal("",            result[4])
    assert.are.equal("",            result[5])
    assert.are.equal("1. separate", result[6])  -- not renumbered
  end)

  it("renumbers loose list with nested children", function()
    local result = recalc_buf_loose({
      "1. parent",
      INDENT .. "1. child a",
      INDENT .. "1. child b",
      "",
      "1. second parent",
    }, 1)

    assert.are.equal("1. parent",                result[1])
    assert.are.equal(INDENT .. "1. child a",     result[2])
    assert.are.equal(INDENT .. "2. child b",     result[3])
    assert.are.equal("",                         result[4])
    assert.are.equal("2. second parent",         result[5])
  end)

  it("finds list start when cursor is on a middle item", function()
    local result = recalc_buf_loose({
      "1. first",
      "",
      "1. second",
      "",
      "1. third",
    }, 3)

    assert.are.equal("1. first",  result[1])
    assert.are.equal("",          result[2])
    assert.are.equal("2. second", result[3])
    assert.are.equal("",          result[4])
    assert.are.equal("3. third",  result[5])
  end)

  it("handles indented child loose list", function()
    local result = recalc_buf_loose({
      "1. parent",
      INDENT .. "1. child a",
      INDENT .. "",
      INDENT .. "1. child b",
      "1. second parent",
    }, 1)

    assert.are.equal("1. parent",            result[1])
    assert.are.equal(INDENT .. "1. child a", result[2])
    -- blank line in child scope is preserved
    assert.are.equal(INDENT .. "",           result[3])
    assert.are.equal(INDENT .. "2. child b", result[4])
    assert.are.equal("2. second parent",     result[5])
  end)

  it("does not affect tight lists when loose_lists is false", function()
    -- This uses the standard recalc_buf which has loose_lists = false
    local result = recalc_buf({
      "1. first",
      "",
      "1. should stay 1",
    }, 1)

    assert.are.equal("1. first",         result[1])
    assert.are.equal("",                 result[2])
    assert.are.equal("1. should stay 1", result[3])  -- not renumbered
  end)
end)
