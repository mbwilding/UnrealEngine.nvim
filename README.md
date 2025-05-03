# UnrealEngine.nvim

Supports Linux, Mac, and Windows

## Dependencies

- Source version of Unreal Engine
- clangd (LSP)
- Windows - LLVM (clang-cl): `winget install -e --id LLVM.LLVM`

## Options

[Options](https://github.com/mbwilding/UnrealEngine.nvim/blob/main/lua/unrealengine/types.lua#L7)

> The commands can also be passed the opts directly to allow for different configurations, these will merge with your defaults passed into setup

## Install

### lazy.nvim

```lua
return {
    "mbwilding/UnrealEngine.nvim",
    lazy = false,
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
        auto_generate = false, -- Auto generates the LSP info when enabled
        auto_build = false, -- Auto builds code on save when enabled
        engine_path = "/path/to/UnrealEngine" -- Can also take a table<string>
    }
}
```
