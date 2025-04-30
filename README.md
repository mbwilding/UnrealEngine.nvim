# UnrealEngine.nvim

Supports Linux, Mac, and Windows

## Dependencies

- Source version of Unreal Engine
- clangd (Language Server)
- Windows: winget install -e --id LLVM.LLVM

## Options

[Options](https://github.com/mbwilding/UnrealEngine.nvim/blob/main/lua/unrealengine/types.lua#L7)

> The commands can also be passed the opts directly to allow for different configurations, these will merge with your defaults passed into setup

## Install

### lazy.nvim

```lua
return {
    "mbwilding/UnrealEngine.nvim",
    dependencies = {
        -- optional, this registers the Unreal Engine icon to .uproject files
        "nvim-tree/nvim-web-devicons",
    },
    keys = {
        {
            "<leader>ug",
            function()
                require("unrealengine.commands").generate_lsp()
            end,
            desc = "UnrealEngine: Generate LSP"
        },
        {
            "<leader>ub",
            function()
                require("unrealengine.commands").build()
            end,
            desc = "UnrealEngine: Build"
        },
    },
    opts = {
        engine_path = "/path/to/UnrealEngine"
    }
}
```
