# Changelog

All notable changes to bautolist.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `soft_return` command (`AutolistSoftReturn`) for creating continuation lines aligned to list content column. Bind to `<S-CR>` for a soft return that adds a new line indented to the content column without a bullet.

## [v4.2.1] - 2026-02-20

### Fixed

- Empty ordered list bullets (e.g., `3.`) are now correctly detected and deleted on Enter even when Neovim strips the trailing space from the marker
- Deleting an empty bullet now removes the line entirely instead of clearing it to an empty string, preventing a stale blank line
- With `loose_lists` enabled, pressing Enter on a blank line after a terminated tight list no longer creates a spurious new bullet
- Shift-Tab on a nested bullet with siblings above it now correctly dedents to the parent level instead of jumping to the top-level list (`find_parent_line()` now walks past sibling list items at the same indent)

## [v4.2.0] - 2026-02-09

### Added

- `content_indent` option (default `true`): child list indentation aligns to the parent's content column (marker width + 1 space) instead of using `tabstop`/`shiftwidth`. For example, `1. Hello` → 3-space indent for children, matching CommonMark spec for correct rendering in Quarto and other strict markdown processors. Set to `false` to restore the upstream autolist.nvim behavior of using `tabstop`.
- `get_content_width()`, `find_parent_line()`, and `find_indent_parent_for_tab()` utility helpers in utils.lua

### Fixed

- Quarto fragment separator (`. . .`) no longer triggers a roman numeral list (roman pattern required zero-or-more uppercase letters; now requires one-or-more)
- Bold/italic markup (`**text**`, `*text*`) no longer triggers an unordered `*` list (`is_list()` and `get_bullet_from()` now require whitespace after the marker)

## [v4.1.0] - 2026-02-09

### Added

- Experimental `loose_lists` option (opt-in, default `false`): when enabled, single blank lines between list items are treated as part of the same list (CommonMark "loose lists"). Two consecutive blank lines still terminate a list.
- `is_blank_line()` utility helper in utils.lua
- Tests for loose list recalculation, backward walk, double-blank termination, and nested children (75 total tests)

### Fixed

- `set_line_marker()` now always preserves a space after the marker, fixing cursor placement after shift-tab on empty bullets (cursor was landing on the dot instead of after the space)

## [v4.0.0] - 2026-02-07

### Added

- Test suite using busted + nlua (spec/numbers_spec.lua, spec/utils_spec.lua, spec/config_spec.lua)
- CI via GitHub Actions (nvim-neorocks/nvim-busted-action) running against stable and nightly Neovim
- Rockspec for luarocks-based test dependency management
- Makefile for local test execution
- Integration tests for `recalculate()` covering child list reset, multi-level nesting, alphabetic lists, and unordered lists (spec/recalculate_spec.lua)

### Changed

- Forked from gaoDean/autolist.nvim and renamed to brentonk/bautolist.nvim
- Updated README with new repo name, badges, and attribution
- Replaced deprecated `nvim_buf_get_option` calls with `vim.bo` in treesitter module
- Removed stray `print()` debug statement from list cycling function

### Fixed

- `recalculate()` now resets indented ordered child lists to 1 (gaoDean/autolist.nvim#82)
- Identified pre-existing bug: `arabic2roman(1999)` returns `"MIM"` instead of `"MCMXCIX"`
