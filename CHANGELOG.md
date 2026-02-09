# Changelog

All notable changes to bautolist.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `content_indent` option (default `true`): child list indentation aligns to the parent's content column (marker width + 1 space) instead of using `tabstop`/`shiftwidth`. For example, `1. Hello` → 3-space indent for children, matching CommonMark spec for correct rendering in Quarto and other strict markdown processors. Set to `false` to restore the upstream autolist.nvim behavior of using `tabstop`.
- `get_content_width()`, `find_parent_line()`, and `find_indent_parent_for_tab()` utility helpers in utils.lua

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
