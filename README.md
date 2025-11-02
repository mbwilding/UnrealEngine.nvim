# UnrealEngine.nvim

A seamless integration between Neovim and Unreal Engine, providing a complete development experience for Unreal Engine C++ projects. This plugin consists of two components that work together:

1. **Unreal Engine Plugin** (`NeovimSourceCodeAccess`) - Integrates Neovim as the source code editor within Unreal Engine, enabling bidirectional communication between Unreal Engine and your Neovim session.

2. **Neovim Plugin** (`unrealengine`) - Manages LSP configuration (clangd), provides build commands, and automates common Unreal Engine development tasks.

When you click on source files in Unreal Engine or use "Open in External Editor", files automatically open in your running Neovim instance at the correct line and column. The Neovim plugin handles project builds, LSP setup, and generates the necessary configuration files for a complete IDE experience.

> Supports Linux, Mac, and Windows

## Features

- **Bidirectional file synchronization**: Click files in Unreal Engine to open them in Neovim at the correct location
- **Automatic LSP setup**: Generates `compile_commands.json` and `.clangd` configuration for clangd
- **Build integration**: Build, rebuild, and clean your Unreal Engine projects directly from Neovim
- **Auto-build on save**: Optionally build C++ files automatically when saved
- **Plugin management**: Automatically links and builds the Unreal Engine plugin into your engine installation
- **Editor launching**: Launch Unreal Editor from Neovim with proper environment setup

## Dependencies

- Source version of Unreal Engine (not the launcher version)
- clangd (Language Server Protocol)
- Windows - LLVM (clang-cl): `winget install -e --id LLVM.LLVM`

## Installation

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
            desc = "UnrealEngine: Open Editor"
        },
        {
            "<leader>uc",
            function()
                require("unrealengine.commands").clean()
            end,
            desc = "UnrealEngine: Clean"
        },
        {
            "<leader>ue",
            function()
                require("unrealengine.commands").build_engine()
            end,
            desc = "UnrealEngine: Link Plugin - Build Engine"
        },
    },
    -- Optional, this will update and build the Unreal Engine plugin on update
    build = function()
        -- Path required to be passed in
        require("unrealengine.commands").build_engine({ engine_path = "/path/to/UnrealEngine" })
    end,
    opts = {
        auto_generate = true, -- Auto generates LSP info when detected in CWD | default: false
        auto_build = true, -- Auto builds on save | default: false
        engine_path = "/path/to/UnrealEngine", -- Path to your UnrealEngine source directory
        build_type = "Development", -- Build type: "DebugGame", "Development", or "Shipping"
        with_editor = true, -- Build with editor | default: true
        register_icon = true, -- Register Unreal Engine icon for .uproject files | default: true
        register_filetypes = true, -- Register .uproject and .uplugin as JSON | default: true
        close_on_success = true, -- Close terminal split on successful builds | default: true
        environment_variables = nil, -- Environment variables to pass when launching editor (Linux/Mac only)
    }
}
```

## Configuration Options

All configuration options are documented in [`lua/unrealengine/types.lua`](lua/unrealengine/types.lua).

> **Note**: The commands can also be passed options directly to allow for different configurations. These will merge with your defaults passed into `setup()`.

### Available Options

- `engine_path` (string, required) - Path to your Unreal Engine source directory
- `auto_generate` (boolean, default: `false`) - Automatically generates LSP configuration when a `.uproject` file is detected
- `auto_build` (boolean, default: `false`) - Automatically builds C++ files on save
- `build_type` (string, default: `"Development"`) - Build type: `"DebugGame"`, `"Development"`, or `"Shipping"`
- `with_editor` (boolean, default: `true`) - Build with editor enabled
- `register_icon` (boolean, default: `true`) - Register Unreal Engine icon for `.uproject` files (requires nvim-web-devicons)
- `register_filetypes` (boolean, default: `true`) - Register `.uproject` and `.uplugin` files as JSON
- `close_on_success` (boolean, default: `true`) - Close terminal split automatically when builds succeed
- `environment_variables` (table, default: `nil`) - Environment variables to pass when launching editor (Linux/Mac only)

## Commands

### `generate_lsp()`
Generates the clangd LSP cache by running Unreal Build Tool with `GenerateClangDatabase` mode. This creates `compile_commands.json` and sets up `.clangd` configuration files.

### `build()`
Builds your Unreal Engine project and automatically regenerates LSP configuration after the build completes.

### `rebuild()`
Cleans the project first, then builds it. Equivalent to running `clean()` followed by `build()`.

### `clean()`
Removes generated files including:
- `Binaries/`
- `Intermediate/`
- `Saved/`
- `compile_commands.json`
- `.clangd` files
- Plugin build artifacts

### `open()`
Launches Unreal Editor with your project. If `uproject_path` is set in options, it will launch with that specific project.

### `build_engine()`
Links the `NeovimSourceCodeAccess` plugin into your Unreal Engine installation and builds it. This is how you install/update the Unreal Engine plugin component.

## Unreal Engine Plugin Setup

### Initial Installation

1. Run `require("unrealengine.commands").build_engine()` (or use your keybinding like `<leader>ue`). This will:
   - Create a symbolic link from the plugin source to your Unreal Engine installation
   - Build the Unreal Editor with the plugin included

2. Set Neovim as the source code editor in Unreal Engine:
   - Open Unreal Engine
   - Navigate to **Edit > Editor Preferences**
   - In the sidebar under **General**, click the **Source Code** section
   - Change **Source Code Editor** to `Neovim` from the dropdown menu
   - Do **not** click restart; simply close the editor

3. **Launch Unreal Engine from Neovim** using `require("unrealengine.commands").open()` (or `<leader>uo`). This is important because:
   - The Unreal Engine plugin uses the `NVIM` environment variable to communicate with your Neovim instance
   - Launching from Neovim ensures this variable is set correctly

### How It Works

The Unreal Engine plugin (`NeovimSourceCodeAccess`) implements Unreal's `ISourceCodeAccessor` interface and communicates with Neovim using its remote server functionality. When you:
- Click a file in Unreal Engine's editor
- Use "Go to Definition" or similar navigation
- Use "Open in External Editor"

The plugin sends remote commands to your Neovim instance via `nvim --remote`, opening files at the correct line and column numbers.

### Updating the Plugin

To update the Unreal Engine plugin after updating the Neovim plugin:

1. Simply run `build_engine()` again - it will update the symlink and rebuild
2. Or configure the `build` function in your lazy.nvim config to automatically update on plugin updates (see installation example above)

## Usage Workflow

1. **Initial Setup**:
   - Configure the plugin with your `engine_path`
   - Run `build_engine()` to install the Unreal Engine plugin
   - Set Neovim as the editor in Unreal Engine preferences

2. **Starting Development**:
   - Launch Unreal Engine from Neovim using `open()` command
   - The plugin automatically generates LSP configuration if `auto_generate` is enabled
   - Start editing C++ files with full LSP support

3. **During Development**:
   - Click files in Unreal Engine to open them in Neovim
   - Use build commands (`<leader>ub`, `<leader>ur`) to compile your code
   - Enable `auto_build` to automatically build on save
   - LSP configuration is automatically regenerated after builds

## Troubleshooting

- **Files not opening in Neovim**: Make sure you launched Unreal Engine from Neovim (not directly), as the `NVIM` environment variable must be set
- **LSP not working**: Run `generate_lsp()` to create `compile_commands.json` and `.clangd` configuration
- **Plugin not found in Unreal Engine**: Run `build_engine()` to link and compile the plugin into your engine
- **Build failures**: Ensure you're using the source version of Unreal Engine, not the launcher version
