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
        {
            "<leader>ur",
            function()
                require("unrealengine.commands").rebuild()
            end,
            desc = "UnrealEngine: Rebuild"
        },
        {
            "<leader>uo",
            function()
                require("unrealengine.commands").open()
            end,
            desc = "UnrealEngine: Open"
        },
        {
            "<leader>uc",
            function()
                require("unrealengine.commands").clean()
            end,
            desc = "UnrealEngine: Clean",
        },
        {
            "<leader>ue",
            function()
                require("unrealengine.commands").build_engine()
            end,
            desc = "UnrealEngine: Link Plugin - Build Engine",
        },
    },
    opts = {
        auto_generate = true, -- Auto generates LSP info when detected in CWD | default: false
        auto_build = true, -- Auto builds on save | default: false
        engine_path = "/path/to/UnrealEngine", -- Path to your UnrealEngine source directory, you can also provide a table of strings
        -- More settings are in the `lua/unrealengine/init.lua` file
    }
}
```

## Unreal Engine Plugin

> **NEW**

If you run `require("unrealengine.commands").build_engine()` (or map it as shown above with `<leader>ue`), it will link the Unreal Engine plugin that connects Neovim to Unreal Engine and build it. This will be how you update the plugin after updating the Neovim plugin with your package manager. **Note:** You must launch the editor via the Neovim plugin to establish the link for that Neovim instance.

To set the source control plugin to Neovim in Unreal Engine:

1. **Open** Unreal Engine.
2. Navigate to **Edit > Editor Preferences**.
3. In the sidebar under **General**, click the **Source Code** section.
4. Change **Source Code Editor** to `Neovim` from the dropdown menu.
5. Do **not** click restart; simply close the editor.
6. **Launch Unreal Engine from Neovim.**
