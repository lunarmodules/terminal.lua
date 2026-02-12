# Guidance for AI agents

This file is the main entry point for AI tools working in this repository. It provides project context and points to authoritative sources for conventions.

## What this project is

terminal.lua is a cross-platform terminal library for Lua (Windows/Unix/Mac). It provides terminal handling, text handling, and UI building blocks (panels, prompts, etc.).

## Project layout

| Path | Purpose |
|------|---------|
| `src/terminal/` | Lua source (modules under `terminal.*`, `terminal.cli.*`, `terminal.ui.*`) |
| `spec/` | Tests (Busted); mirror source layout where relevant |
| `examples/` | Example scripts |
| `doc_topics/` | Documentation source (markdown); generated output in `docs/` |
| `experimental/` | Experimental or non-stable code |
| `.luacheckrc` | LuaCheck lint configuration (authoritative for lint) |
| `.editorconfig` | Editor/formatting preferences |
| `config.ld` | ldoc configuration for API docs |

Spec files live in a flat `spec/` directory and are named by module (e.g. `18-prompt_spec.lua` for `terminal.cli.prompt`).

## Conventions and workflow

Details are in **[CONTRIBUTING.md](CONTRIBUTING.md)**. Summary:

- **Getting started:** Use the `Makefile` from the repository root; LuaRocks should use the user tree (see CONTRIBUTING).
- **Commits:** Atomic commits, [conventional-commits](https://www.conventionalcommits.org/) format (type + scope, present tense, 50-char header, 72-char body).
- **Testing:** `make test` (Busted), `make lint` (LuaCheck). Coverage: LuaCov, output in `luacov.report.out`. Every new feature, function, or component must be accompanied by tests where reasonable and applicable; exceptions are documented (see CONTRIBUTING).
- **Documentation:** ldoc; sources in `config.ld`. Run `make docs` to generate; do not commit generated docs (`make clean` will revert generated docs). Update comments and examples during development.

## Test isolation

In Busted the test files are ran as Lua files, all `describe` blocks are executed at load time. All other blocks only at test-runtime. Hence all initialization MUST be in `setup` and `before_each` blocks, and NEVER in `describe` blocks. The variables to hold the setup-stuff can be defined at the `describe` level (to keep them in scope for all tests within the block), but no values should be assigned to them at that point.
The only exception is code that generates tests, like table-tests, etc. since they are designed to run at the `describe` level.

For example:

    describe("some block", function()

      local my_module    -- only define here, no values!

      setup(function()
        my_module = require "my.module.something"   -- initialize the value here
      end)

      it("a test", function()
        -- test goes here
      end)
    end)


## Code style

Code style is defined by [.luacheckrc](.luacheckrc) and [.editorconfig](.editorconfig). Follow CONTRIBUTING’s “Code style” section when present.

In Busted test files in `./spec` the vertical whitespace is important:
- 3 lines between `describe` blocks
- 1 line at the start of a `describe` block
- 2 lines between other blocks (`it`, `setup`, `before_each`, etc)
- 3 lines between initialization (`setup`/`teardown`/etc) and the first `it` or `describe` block
- 1 line between multiple closing `end)` statements

For functionality that requires more than 3 cases of input to be tested, table-test-style is prefered. But only if it enhances maintainability and readability.

When unit testing functions or methods, each function should have its own `describe` block inside the module-level `describe`. This keeps tests grouped by functions and provides a clear structure. 

Example:

    describe("terminal.draw", function()

      describe("title_seq()", function()
        
        it("returns a sequence for a simple title", function()
           -- implementation here 
        end)
      
      end)



      describe("title()", function()
      
        it("writes the same output as title_seq()", function()
          -- implementation here
        end)
      
      end)

    end)

## Architecture

High-level design and module boundaries will be described in **[ARCHITECTURE.md](ARCHITECTURE.md)**.

## Other references

- [CHANGELOG.md](CHANGELOG.md) — version history and SemVer
- [LICENSE.md](LICENSE.md) — license and copyright
- [Online documentation](https://lunarmodules.github.io/terminal.lua/) — API and usage
