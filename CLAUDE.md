# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

bautolist.nvim is a Neovim plugin (forked from gaoDean/autolist.nvim) that automatically manages list continuation, renumbering, indentation, checkbox toggling, and bullet cycling in markdown, text, norg, and LaTeX files.

## Commands

### Running Tests

```bash
make test                    # Run full suite (75+ tests)
```

To run a single spec file:

```bash
eval $(luarocks path --lua-version 5.1) && \
  ~/.luarocks/bin/nlua ~/.luarocks/lib/luarocks/rocks-5.1/busted/2.3.0-1/bin/busted \
  --ignore-lua spec/recalculate_spec.lua
```

To run a single test by name pattern:

```bash
eval $(luarocks path --lua-version 5.1) && \
  ~/.luarocks/bin/nlua ~/.luarocks/lib/luarocks/rocks-5.1/busted/2.3.0-1/bin/busted \
  --ignore-lua --filter "resets an indented child list"
```

### Installing Test Dependencies

```bash
luarocks --local --lua-version 5.1 install nlua LUA_INCDIR=/usr/include/luajit-2.1
luarocks --local --lua-version 5.1 install busted LUA_INCDIR=/usr/include/luajit-2.1
```

## Architecture

### Module Dependency Graph

```
init.lua  (setup + Vim command registration)
├── config.lua  (state: list patterns, tab/indent settings, checkbox config)
└── auto.lua    (core logic: recalculate, new_bullet, checkbox, cycling)
    ├── config.lua
    ├── utils.lua  (list detection, marker manipulation, buffer helpers)
    │   └── numbers.lua  (roman numeral ↔ arabic conversion)
    └── treesitter.lua  (code fence detection to suppress list behavior)
```

### Key Concepts

**List patterns** are Lua patterns defined in `config.lua` (`list_patterns` table) and grouped by filetype in `config.lists`. The pattern types are: unordered (`[-+*]`), digit (`%d+[.)]`), ascii (`%a[.)]`), roman (`%u*[.)]`), neorg (`%-` repeated), and latex (`\\item`).

**`recalculate()`** (`auto.lua`) is the central algorithm. It walks a list from its start, renumbering ordered items sequentially. For child lists (detected by `list_indent + config.tabstop`), it recurses with `override_start_num` set to the child's first line number. The `reset_list` variable controls whether the first item is reset to 1.

**`exec_ordered()`** (`utils.lua`) is the dispatch pattern used throughout: it takes an entry string and three callbacks (digit, char, roman) plus a fallback, matches the entry against each ordered type, and calls the appropriate handler. This powers `get_value_ordered`, `get_ordered_add`, `set_ordered_value`, and `is_ordered`.

**Config initialization** (`config.update()`) computes runtime values from Vim options: `config.tabstop` comes from `vim.opt.tabstop:get()` when `expandtab` is on, or is set to `1` when using real tabs. `config.tab` is the corresponding whitespace string.

### Plugin Registration

`init.lua:setup()` iterates over all functions in `auto.lua` and registers each as a Vim command (e.g., `auto.recalculate` → `:AutolistRecalculate`). Users bind keys to these commands.

## Testing Patterns

Tests use **busted** (Lua test framework) run through **nlua** (Neovim-as-Lua-interpreter). The `.busted` config sets `lpath = "lua/?.lua;lua/?/init.lua"` so `require("autolist.foo")` resolves correctly.

- **Unit tests** (`spec/utils_spec.lua`, `spec/numbers_spec.lua`, `spec/config_spec.lua`): test pure functions directly.
- **Integration tests** (`spec/recalculate_spec.lua`): create real Neovim buffers via `vim.api.nvim_create_buf`, set filetype/options, populate lines, position cursor, call `auto.recalculate()`, then assert on buffer contents. Must set `expandtab = true` and a specific `tabstop` before `config.update()` so `config.tabstop` matches the indent strings used in test data.

## Branching Workflow

- **`main`** — stable/release branch. Only receives merges from `develop` when ready to release.
- **`develop`** — integration branch for new features and fixes. Push new work here.

Workflow:
1. Create feature commits on `develop` (or on a feature branch merged into `develop`).
2. Push `develop` so it can be tested (user points their plugin manager at the `develop` branch).
3. When satisfied, merge `develop` into `main` and tag a new release.

When making changes, always branch from and push to `develop` unless explicitly told otherwise. Never push untested work directly to `main`.

Before committing, ensure **CHANGELOG.md** and **README.md** are up to date:
- Add new entries under `## [Unreleased]` in CHANGELOG.md for any added, changed, or fixed items.
- If a commit adds or changes a user-facing config option, update the config block in README.md to match.
- If a commit changes behavior relative to upstream autolist.nvim (new feature, bug fix, default change), update the **"Differences from autolist.nvim"** section in README.md.

## Known Issues

- `numbers.arabic2roman(1999)` returns `"MIM"` instead of `"MCMXCIX"` (subtractive notation bug).
