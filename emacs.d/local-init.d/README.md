# Local extension hooks

Drop user-specific `.el` files in this directory to extend the base container config.

Examples:

- `10-keys.el` for keybindings
- `20-theme.el` for appearance
- `30-company.el` for completion tweaks

Files are loaded in lexical filename order from `init.el`.
