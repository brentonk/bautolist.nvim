# Changelog

All notable changes to bautolist.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Test suite using busted + nlua (spec/numbers_spec.lua, spec/utils_spec.lua, spec/config_spec.lua)
- CI via GitHub Actions (nvim-neorocks/nvim-busted-action) running against stable and nightly Neovim
- Rockspec for luarocks-based test dependency management
- Makefile for local test execution

### Changed

- Forked from gaoDean/autolist.nvim and renamed to brentonk/bautolist.nvim
- Updated README with new repo name, badges, and attribution
- Replaced deprecated `nvim_buf_get_option` calls with `vim.bo` in treesitter module
- Removed stray `print()` debug statement from list cycling function

### Fixed

- Identified pre-existing bug: `arabic2roman(1999)` returns `"MIM"` instead of `"MCMXCIX"`
