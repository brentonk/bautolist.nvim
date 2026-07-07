local utils = require("autolist.utils")
local config = require("autolist.config")

local fn = vim.fn
local pat_checkbox = "^%s*%S+%s%[.%]"
local pat_colon = ":%s*$"
local checkbox_filled_pat = config.checkbox.left
.. config.checkbox.fill
.. config.checkbox.right
local checkbox_empty_pat = config.checkbox.left .. " " .. config.checkbox.right
-- filter_pat() removes the % signs
local checkbox_filled = utils.get_percent_filtered(checkbox_filled_pat)
local checkbox_empty = utils.get_percent_filtered(checkbox_empty_pat)

local new_before_pressed = false
local next_keypress = ""
local edit_mode = "n"

local M = {}

local function press(key, mode)
  if not key or key == "" then return end
  local parsed_key = vim.api.nvim_replace_termcodes(key, true, true, true)
  if mode == "i" then
    vim.cmd.normal({ "a" .. parsed_key, bang = true })
  else
    vim.cmd.normal({ parsed_key, bang = true })
  end
end

-- returns the correct lists for the current filetype
local function get_lists()
  -- each table in filetype lists has the key of a filetype
  -- each value has the tables (of lists) that it is assigned to
  return config.lists[vim.bo.filetype]
end

-- recalculates the current list scope
function M.recalculate(override_start_num)
  -- the var base names: list and line
  -- x is the actual line (fn.getline)
  -- x_num is the line number (fn.line)
  -- x_indent is the indent of the line (utils.get_indent_lvl)

  local types = get_lists()
  local list_start_num
  local reset_list = 0
  if override_start_num then
    list_start_num = override_start_num
  else
    list_start_num = utils.get_list_start(fn.line("."), types)
  end
  if not list_start_num then return end -- returns nil if not ordered list
  local list_start_line = fn.getline(list_start_num)
  if not utils.is_list(list_start_line, types) then return end
  if reset_list then
    local next_num = list_start_num + reset_list
    local nxt = fn.getline(next_num)
    if utils.is_ordered(nxt) then
      fn.setline(next_num, utils.set_ordered_value(nxt, 1))
    end
  end
  local list_start = fn.getline(list_start_num)
  local list_indent = utils.get_indent_lvl(list_start)

  local target = utils.get_value_ordered(list_start) + 1 -- start plus one
  local linenum = list_start_num + 1
  local line = fn.getline(linenum)
  local line_indent = utils.get_indent_lvl(line)
  local prev_indent = -1

  while linenum < list_start_num + config.list_cap do
    local is_blank = config.loose_lists and utils.is_blank_line(line)

    -- blank line handling for loose lists
    if is_blank then
      local next_line = fn.getline(linenum + 1)
      if utils.is_list(next_line, types)
        and utils.get_indent_lvl(next_line) >= list_indent then
        -- skip this blank line, continue to next
        linenum = linenum + 1
        line = fn.getline(linenum)
        line_indent = utils.get_indent_lvl(line)
        -- fall through to process this line normally below
      else
        return
      end
    end

    -- indent check (not applied to blank lines, which were already handled)
    if not is_blank and line_indent < list_indent then
      return
    end

    if utils.is_list(line, types) then
      if line_indent == list_indent then
        local val = utils.set_ordered_value(list_start, target)
        utils.set_line_marker(
          linenum,
          utils.get_marker(val, types),
          types
        )
        target = target + 1 -- only increase target if increased list
        prev_indent = -1 -- escaped the child list
      elseif
        line_indent ~= prev_indent -- small difference between var names
        and line_indent == list_indent + (config.content_indent_enabled()
          and (utils.get_content_width(list_start, types) or config.indent_width())
          or config.indent_width())
      then
        -- this part recalculates a child list with recursion
        -- the prev_indent prevents it from recalculating multiple times.
        -- the first time this runs, linenum is the first entry in the list
        M.recalculate(linenum)
        prev_indent = line_indent -- so you don't repeat recalculate()
      end
    else
      return
    end
    -- do these at the end so it can check it at the start of the loop
    linenum = linenum + 1
    line = fn.getline(linenum)
    line_indent = utils.get_indent_lvl(line)
  end
end

function M.new_bullet_before()
  return M.new_bullet(true)
end

local function get_bullet_from(line, pattern)
  local matched_bare = line:match("^%s*"
    .. pattern
    .. "%s+") -- only bullet, require space after marker
  local matched_with_checkbox = line:match("^%s*"
    .. pattern
    .. "%s+"
    .. "%[.%]"
    .. "%s*") -- bullet and checkbox
  local matched_eol = line:match("^%s*"
    .. pattern
    .. "%s*$") -- bare marker at end of line (no content after)

  return matched_with_checkbox or matched_bare or matched_eol
end

local function is_in_code_fence()
  -- check if Treesitter parser is installed, and if so, check if we're in a markdown code fence
  local parser = require('autolist.treesitter')
    :new(vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win())
  return parser and parser:is_in_markdown_code_fence()
end

local function find_suitable_bullet(line, filetype_lists, del_above)
  -- ipairs is used to optimise list_types (and say who has priority)
  for i, filetype_specific_pattern in ipairs(filetype_lists) do
    local bullet = get_bullet_from(line, filetype_specific_pattern)

    if bullet then
      if string.len(line) == string.len(bullet) then
        -- empty bullet, delete it
        local del_linenum = fn.line(".") - (del_above and 1 or -1)
        vim.api.nvim_buf_set_lines(0, del_linenum - 1, del_linenum, false, {})
        utils.reset_cursor_column()
        return nil
      end
      return bullet
    end
  end
end


function M.new_bullet(prev_line_override)
  local filetype_lists = get_lists()
  if not filetype_lists then return nil end
  if is_in_code_fence() then return nil end

  -- if new_bullet_before, prev_line should be the line below
  local prev_line_num = fn.line(".") + (prev_line_override and 1 or -1)
  local prev_line = fn.getline(prev_line_num)
  local cur_line = fn.getline(".")
  local bullet = find_suitable_bullet(prev_line,
    filetype_lists,
    not prev_line_override)

  -- If prev_line is a continuation line (not a list item, not blank),
  -- walk upward to find the parent list item and create a sibling bullet.
  -- Track the parent's line number for loose list detection below.
  local continuation_parent_num = nil
  if not bullet and not prev_line_override
    and not utils.is_blank_line(prev_line)
    and not utils.is_list(prev_line, filetype_lists) then
    local search_num = prev_line_num - 1
    while search_num >= 1 do
      local search_line = fn.getline(search_num)
      if utils.is_blank_line(search_line) then break end
      if utils.is_list(search_line, filetype_lists) then
        -- Verify the continuation line's indent matches the list item's content column
        local prev_indent = utils.get_indent_lvl(prev_line)
        local list_indent = utils.get_indent_lvl(search_line)
        local content_width
        if config.content_indent_enabled() then
          content_width = utils.get_content_width(search_line, filetype_lists) or config.indent_width()
        else
          content_width = config.indent_width()
        end
        if prev_indent == list_indent + content_width then
          bullet = find_suitable_bullet(search_line, filetype_lists, false)
          continuation_parent_num = search_num
        end
        break
      end
      search_num = search_num - 1
    end
  end

  -- in loose mode, if prev_line is blank, look one more line back
  if not bullet and config.loose_lists and utils.is_blank_line(prev_line)
    and not prev_line_override then
    local farther_num = prev_line_num - 1
    if farther_num >= 1 then
      local farther_line = fn.getline(farther_num)
      -- Only use this fallback when the list above is actually
      -- loose-formatted (blank line between two list items).  A tight
      -- list followed by a single blank is a terminated list.
      local is_actually_loose = false
      if farther_num >= 3 then
        local above = fn.getline(farther_num - 1)
        if utils.is_blank_line(above)
          and utils.is_list(fn.getline(farther_num - 2), filetype_lists) then
          is_actually_loose = true
        end
      end
      if is_actually_loose then
        for _, pat in ipairs(filetype_lists) do
          local b = get_bullet_from(farther_line, pat)
          if b then
            -- check it's not an empty bullet
            if string.len(farther_line) > string.len(b) then
              bullet = b
              break
            end
          end
        end
      end
    end
  end

  bullet = bullet and utils.get_ordered_add(bullet, 1) -- add 1 if ordered list

  if prev_line:match(pat_colon)
    and (config.colon.indent_raw
    or (bullet and config.colon.indent)) then
    local indent_str
    if config.content_indent_enabled() then
      local cw = utils.get_content_width(prev_line, filetype_lists)
      indent_str = string.rep(" ", (cw or config.indent_width()) + utils.get_indent_lvl(prev_line))
    else
      indent_str = config.indent_string() .. prev_line:match("^%s*")
    end
    bullet = indent_str .. config.colon.preferred .. " "
  end

  if bullet then -- insert bullet
    -- in loose mode, detect if the list uses loose spacing and insert a blank line
    if config.loose_lists and not prev_line_override then
      -- When coming from a continuation line, check looseness from the
      -- parent list item rather than the continuation line itself.
      local check_num = continuation_parent_num or prev_line_num
      -- if we already looked past a blank line, the list is loose
      local is_loose = utils.is_blank_line(fn.getline(prev_line_num))
      if not is_loose and check_num >= 2 then
        -- check if the line above prev_line is blank (indicating loose list)
        local above = fn.getline(check_num - 1)
        if utils.is_blank_line(above) and check_num >= 3 then
          local above_above = fn.getline(check_num - 2)
          if utils.is_list(above_above, filetype_lists) then
            is_loose = true
          end
        end
      end
      if is_loose then
        local cur_linenum = fn.line(".")
        -- insert a blank line above the current line
        vim.api.nvim_buf_set_lines(0, cur_linenum - 1, cur_linenum - 1, false, { "" })
        -- cursor moves down by one due to the insertion
        vim.api.nvim_win_set_cursor(0, { cur_linenum + 1, 0 })
      end
    end
    utils.set_current_line(bullet .. cur_line:gsub("^%s*", "", 1))
  end
end

function M.soft_return()
  local filetype_lists = get_lists()
  if not filetype_lists then return nil end
  if is_in_code_fence() then return nil end

  local prev_line = fn.getline(fn.line(".") - 1)
  local cur_line = fn.getline(".")

  if not utils.is_list(prev_line, filetype_lists) then return nil end

  local prev_indent = utils.get_indent_lvl(prev_line)
  local content_width
  if config.content_indent_enabled() then
    content_width = utils.get_content_width(prev_line, filetype_lists) or config.indent_width()
  else
    content_width = config.indent_width()
  end
  local target = prev_indent + content_width
  utils.set_current_line(string.rep(" ", target) .. cur_line:gsub("^%s*", "", 1))
  utils.reset_cursor_column(fn.col("$"))
end

-- othewise it runs too fast and feedkeys doesn't register commands
local function run_recalculate_after_delay()
  vim.loop.new_timer():start(0, 0, vim.schedule_wrap(function()
    M.recalculate()
  end))
end

local function handle_indent(before, after)
  local filetype_lists = get_lists()
  local current_line_is_list = utils.is_list(fn.getline("."), filetype_lists)
  local cur_line = fn.getline(".")
  if current_line_is_list
    and fn.getpos(".")[3] - 1 == string.len(cur_line) -- cursor on last char of line
  then
    if config.content_indent_enabled() then
      local linenum = fn.line(".")
      local cur_indent = utils.get_indent_lvl(cur_line)
      local content = cur_line:gsub("^%s*", "", 1)
      if after == "<c-t>" then
        -- Tab: indent to parent's content column
        local _, parent = utils.find_indent_parent_for_tab(linenum, filetype_lists)
        if parent then
          local parent_indent = utils.get_indent_lvl(parent)
          local parent_cw = utils.get_content_width(parent, filetype_lists) or config.indent_width()
          local target = parent_indent + parent_cw
          fn.setline(linenum, string.rep(" ", target) .. content)
        else
          fn.feedkeys(vim.api.nvim_replace_termcodes(after, true, true, true))
        end
      else
        -- Shift-Tab: dedent to parent's indent level
        local _, parent = utils.find_parent_line(linenum, filetype_lists)
        if parent then
          local target = utils.get_indent_lvl(parent)
          fn.setline(linenum, string.rep(" ", target) .. content)
        else
          -- already at top level or no parent, dedent to column 0
          fn.setline(linenum, content)
        end
      end
      utils.reset_cursor_column(fn.col("$"))
      run_recalculate_after_delay()
    else
      fn.feedkeys(vim.api.nvim_replace_termcodes(after, true, true, true))
      run_recalculate_after_delay()
    end
  else
    press(before, "i")
  end
end

function M.shift_tab()
  handle_indent("<s-tab>", "<c-d>")
end

function M.tab()
  handle_indent("<tab>", "<c-t>")
end

local function checkbox_is_filled(line)
  if line:match(checkbox_filled_pat) then
    return true
  elseif line:match(checkbox_empty_pat) then
    return false
  end
end

function M.toggle_checkbox()
  local cur_line = fn.getline(".")
  local filled = checkbox_is_filled(cur_line)
  if filled == true then
    -- replace current line's empty checkbox with filled checkbox
    fn.setline(".", (cur_line:gsub(checkbox_filled_pat, checkbox_empty, 1)))
    -- it is a checkbox, but not empty
  elseif filled == false then
    -- replace current line's filled checkbox with empty checkbox
    fn.setline(".", (cur_line:gsub(checkbox_empty_pat, checkbox_filled, 1)))
  end
end

local function index_of(str, list)
  for i, v in ipairs(list) do
    if v == str then
      return i
    end
  end
end

local function cycle(cycle_backward)
  local filetype_lists = get_lists()
  local list_start = utils.get_indent_list_start(fn.line("."), filetype_lists)

  if not list_start then return nil end

  local current_bullet_type = utils.get_marker(fn.getline(list_start), filetype_lists)
  local stripped_bullet = utils.get_whitespace_trimmed(current_bullet_type)
  local index_in_cycle = index_of(stripped_bullet, config.cycle)

  if not index_in_cycle then return nil end

  local target_index = index_in_cycle + (cycle_backward and -1 or 1)

  if target_index > #config.cycle then target_index = 1 end
  if target_index <= 0 then target_index = #config.cycle end

  local target_bullet = config.cycle[target_index]

  utils.set_line_marker(list_start, target_bullet, filetype_lists)
  M.recalculate()
end


-- with dotrepeat
function M.cycle_next_dr(motion)
  if motion == nil then
    vim.o.operatorfunc = "v:lua.require'autolist'.cycle_next_dr"
    return "g@l"
  end
  for i = 1, vim.v.count1 do
    M.cycle_next()
  end
end

-- with dotrepeat
function M.cycle_prev_dr(motion)
  if motion == nil then
    vim.o.operatorfunc = "v:lua.require'autolist'.cycle_prev_dr"
    return "g@l"
  end
  for i = 1, vim.v.count1 do
    M.cycle_prev()
  end
end

function M.cycle_prev()
  cycle(true)
end

function M.cycle_next()
  cycle()
end

return M
