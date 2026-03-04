# Issue #212 Refactoring: Move Stack Functions Up One Level

## Summary
Successfully refactored the terminal.lua library to flatten the API by moving stack functions from the `.stack` sub-modules to their parent modules. This improves developer experience by reducing the nesting level required to access stack operations.

## API Changes

### Before
```lua
terminal.text.stack.push(attr)
terminal.text.stack.pop()
terminal.text.stack.apply()
terminal.text.stack.push_seq(attr)
terminal.text.stack.pop_seq()
terminal.text.stack.apply_seq()

terminal.scroll.stack.push(top, bottom)
-- etc.
```

### After
```lua
terminal.text.push(attr)
terminal.text.pop()
terminal.text.apply()
terminal.text.push_seq(attr)
terminal.text.pop_seq()
terminal.text.apply_seq()

terminal.scroll.push(top, bottom)
-- etc.
```

## Modules Modified

### 1. **terminal.text** (src/terminal/text/init.lua)
Re-exported functions:
- `push_seq(attr)` → `terminal.text.push_seq(attr)`
- `push(attr)` → `terminal.text.push(attr)`
- `pop_seq(n)` → `terminal.text.pop_seq(n)`
- `pop(n)` → `terminal.text.pop(n)`
- `apply_seq()` → `terminal.text.apply_seq()`
- `apply()` → `terminal.text.apply()`

### 2. **terminal.scroll** (src/terminal/scroll/init.lua)
Re-exported functions:
- `apply_seq()` → `terminal.scroll.apply_seq()`
- `apply()` → `terminal.scroll.apply()`
- `push_seq(top, bottom)` → `terminal.scroll.push_seq(top, bottom)`
- `push(top, bottom)` → `terminal.scroll.push(top, bottom)`
- `pop_seq(n)` → `terminal.scroll.pop_seq(n)`
- `pop(n)` → `terminal.scroll.pop(n)`

### 3. **terminal.cursor.shape** (src/terminal/cursor/shape/init.lua)
Re-exported functions:
- `apply_seq()` → `terminal.cursor.shape.apply_seq()`
- `apply()` → `terminal.cursor.shape.apply()`
- `push_seq(shape)` → `terminal.cursor.shape.push_seq(shape)`
- `push(shape)` → `terminal.cursor.shape.push(shape)`
- `pop_seq(n)` → `terminal.cursor.shape.pop_seq(n)`
- `pop(n)` → `terminal.cursor.shape.pop(n)`

### 4. **terminal.cursor.visible** (src/terminal/cursor/visible/init.lua)
Re-exported functions:
- `apply_seq()` → `terminal.cursor.visible.apply_seq()`
- `apply()` → `terminal.cursor.visible.apply()`
- `push_seq(v)` → `terminal.cursor.visible.push_seq(v)`
- `push(v)` → `terminal.cursor.visible.push(v)`
- `pop_seq(n)` → `terminal.cursor.visible.pop_seq(n)`
- `pop(n)` → `terminal.cursor.visible.pop(n)`

### 5. **terminal.cursor.position** (src/terminal/cursor/position/init.lua)
Re-exported functions:
- `push_seq(new_row, new_column)` → `terminal.cursor.position.push_seq(new_row, new_column)`
- `push(new_row, new_column)` → `terminal.cursor.position.push(new_row, new_column)`
- `pop_seq(n)` → `terminal.cursor.position.pop_seq(n)`
- `pop(n)` → `terminal.cursor.position.pop(n)`

## Documentation Updates

All re-exported stack functions include:
- Full LDoc documentation inherited from the original stack modules
- `@within Stack` annotation to group functions in a separate "Stack" section in generated docs
- `@see` references to the original stack module functions for clarity

This ensures the generated documentation groups stack functions similarly to how "Sequences" and "Functions" are grouped.

## Test Updates

Updated the following test file to use the new API:
- **spec/09-cursor_spec.lua**
  - Changed test descriptions to indicate Stack functions
  - Updated all direct function calls to use the new shorter paths
  - All ~64 test assertions updated

## Example Updates

Updated the following example files to use the new API:
- examples/async.lua
- examples/colors.lua
- examples/headers.lua
- examples/keymap.lua
- examples/panel.lua
- examples/prompt-copas.lua
- examples/prompt.lua
- examples/sequence.lua
- examples/testscreen.lua

## Backward Compatibility

✅ **Full Backward Compatibility Maintained**

The old `.stack.` paths continue to work:
```lua
-- These still work for backward compatibility:
terminal.text.stack.push(attr)
terminal.text.stack.pop()
terminal.scroll.stack.push(top, bottom)
-- etc.
```

This is because:
1. Each parent module still loads its stack sub-module: `M.stack = require("terminal.text.stack")`
2. The re-exported functions are aliases: `M.push = M.stack.push`
3. Existing code will continue to function without modification

## Implementation Details

### Re-export Pattern
Each parent module uses this pattern for stack functions:
```lua
--- Documentation for the function
-- @within Stack
-- @see terminal.text.stack.push
M.push = M.stack.push
```

This approach:
- Creates aliases to the actual stack module functions
- Avoids code duplication
- Maintains semantic clarity through LDoc annotations
- Ensures zero performance overhead

### No Name Collisions
Verified that none of the stack function names (`push`, `pop`, `apply`, `push_seq`, `pop_seq`, `apply_seq`) collide with existing functions on the parent modules.

## Testing & Verification

1. ✓ All init.lua files properly re-export stack functions
2. ✓ All test files updated to use the new API
3. ✓ All example files updated to use the new API
4. ✓ Backward compatibility paths remain accessible
5. ✓ No syntax errors introduced
6. ✓ LDoc annotations properly configured for documentation grouping

## Migration Guide for Users

### For new projects/code:
Use the shorter, flattened syntax:
```lua
terminal.text.push({fg = "red"})
terminal.scroll.push(1, 10)
terminal.cursor.shape.pop()
```

### For existing projects:
No changes required! Both syntaxes work:
```lua
-- Old syntax (still works)
terminal.text.stack.push({fg = "red"})

-- New syntax (now also works)
terminal.text.push({fg = "red"})
```

Gradually migrate to the new syntax at your own pace.
