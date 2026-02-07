# Changelog

All notable changes to bautolist.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
