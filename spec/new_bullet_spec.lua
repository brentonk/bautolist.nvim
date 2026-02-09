-- Integration tests for new_bullet() — especially the interaction between
-- empty-bullet deletion and loose_lists mode.

local auto = require("autolist.auto")
local config = require("autolist.config")

--- Simulate pressing Enter in insert mode at end of line:
--- 1. Insert a blank line below the cursor
--- 2. Move the cursor to the new line
--- 3. Call auto.new_bullet()
local function simulate_enter(buf)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(buf, cursor_line, cursor_line, false, { "" })
  vim.api.nvim_win_set_cursor(0, { cursor_line + 1, 0 })
  auto.new_bullet()
end

--- Helper: create a scratch buffer, set filetype/options, populate lines,
--- position the cursor, and return the buffer handle.
local function make_buf(lines, cursor_line, opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.bo.filetype = "markdown"
  vim.opt.expandtab = true
  vim.opt.tabstop = 4
  config.update({
    loose_lists = (opts and opts.loose) or false,
    content_indent = false,
  })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { cursor_line or #lines, 0 })
  return buf
end

local function get_lines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

-- ──────────────────────────────────────────────────────────────────────────
describe("new_bullet (tight list, loose_lists enabled)", function()
  after_each(function()
    config.update({ loose_lists = false })
  end)

  it("does not create a spurious bullet after three Enters", function()
    local buf = make_buf({ "1. First" }, 1, { loose = true })

    -- Enter 1: should create "2. "
    simulate_enter(buf)
    local r = get_lines(buf)
    assert.are.equal("1. First", r[1])
    assert.are.equal("2. ",      r[2])

    -- Enter 2: empty bullet "2. " should be deleted
    simulate_enter(buf)
    r = get_lines(buf)
    -- After deletion the buffer should be: "1. First", ""
    assert.are.equal(2, #r)
    assert.are.equal("1. First", r[1])
    assert.are.equal("",         r[2])

    -- Enter 3: should NOT create a new bullet
    simulate_enter(buf)
    r = get_lines(buf)
    assert.are.equal(3, #r)
    assert.are.equal("1. First", r[1])
    assert.are.equal("",         r[2])
    assert.are.equal("",         r[3])
  end)

  it("does not create a spurious bullet with stripped trailing space", function()
    -- Simulate Neovim stripping the trailing space: "2." instead of "2. "
    local buf = make_buf({
      "1. First",
      "2.",       -- trailing space stripped by <CR>
    }, 2, { loose = true })

    -- Simulate Enter on bare "2." — should detect empty bullet and delete it
    simulate_enter(buf)
    local r = get_lines(buf)
    assert.are.equal(2, #r)
    assert.are.equal("1. First", r[1])
    assert.are.equal("",         r[2])

    -- Next Enter should NOT create a bullet
    simulate_enter(buf)
    r = get_lines(buf)
    assert.are.equal(3, #r)
    assert.are.equal("1. First", r[1])
    assert.are.equal("",         r[2])
    assert.are.equal("",         r[3])
  end)

  it("does not create a spurious bullet for unordered lists", function()
    local buf = make_buf({ "- First" }, 1, { loose = true })

    -- Enter 1: creates "- "
    simulate_enter(buf)
    local r = get_lines(buf)
    assert.are.equal("- First", r[1])
    assert.are.equal("- ",      r[2])

    -- Enter 2: deletes empty "- "
    simulate_enter(buf)
    r = get_lines(buf)
    assert.are.equal(2, #r)
    assert.are.equal("- First", r[1])
    assert.are.equal("",        r[2])

    -- Enter 3: no spurious bullet
    simulate_enter(buf)
    r = get_lines(buf)
    assert.are.equal(3, #r)
    assert.are.equal("- First", r[1])
    assert.are.equal("",        r[2])
    assert.are.equal("",        r[3])
  end)
end)

-- ──────────────────────────────────────────────────────────────────────────
describe("new_bullet (tight list, loose_lists disabled)", function()
  it("three Enters produce no spurious bullet", function()
    local buf = make_buf({ "1. First" }, 1)

    simulate_enter(buf)
    local r = get_lines(buf)
    assert.are.equal("2. ", r[2])

    simulate_enter(buf)
    r = get_lines(buf)
    assert.are.equal(2, #r)
    assert.are.equal("", r[2])

    simulate_enter(buf)
    r = get_lines(buf)
    assert.are.equal(3, #r)
    assert.are.equal("", r[3])
  end)
end)

-- ──────────────────────────────────────────────────────────────────────────
describe("new_bullet (loose list, loose_lists enabled)", function()
  after_each(function()
    config.update({ loose_lists = false })
  end)

  it("continues a loose list with correct spacing", function()
    local buf = make_buf({
      "1. First",
      "",
      "2. Second",
    }, 3, { loose = true })

    -- Enter after "2. Second": should create "3. " with blank line above
    simulate_enter(buf)
    local r = get_lines(buf)
    -- Expect: 1. First / "" / 2. Second / "" / 3.
    assert.are.equal(5, #r)
    assert.are.equal("1. First",  r[1])
    assert.are.equal("",          r[2])
    assert.are.equal("2. Second", r[3])
    assert.are.equal("",          r[4])
    assert.are.equal("3. ",       r[5])
  end)

  it("does not create a spurious bullet after three Enters in a loose list", function()
    local buf = make_buf({
      "1. First",
      "",
      "2. Second",
    }, 3, { loose = true })

    -- Enter 1: creates "3. " with loose spacing
    simulate_enter(buf)
    local r = get_lines(buf)
    assert.are.equal("3. ", r[5])

    -- Enter 2: empty "3. " deleted
    simulate_enter(buf)
    r = get_lines(buf)
    -- After deletion: 1. First / "" / 2. Second / "" / ""
    -- (the loose blank line + the cursor's blank line remain)
    local found_bullet = false
    for _, line in ipairs(r) do
      if line:match("^%d+%.") then
        -- only "1. First" and "2. Second" should remain
        assert.is_true(line == "1. First" or line == "2. Second",
          "unexpected bullet: " .. line)
      end
    end

    -- Enter 3: should NOT create a bullet
    simulate_enter(buf)
    r = get_lines(buf)
    for _, line in ipairs(r) do
      if line:match("^3%.") or line:match("^4%.") then
        assert.fail("spurious bullet created: " .. line)
      end
    end
  end)
end)
