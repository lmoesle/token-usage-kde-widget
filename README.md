# token-usage-kde-widget

KDE Plasma 6 widget for displaying token usage costs from the `token-usage` CLI.

The widget package id and display name are `lmoesle-token-usage`.

## CLI contract

The widget uses `token-usage` as its base command and runs period-specific raw JSON commands:

```sh
token-usage today --raw
token-usage weekly --raw
token-usage monthly --raw
token-usage yearly --raw
```

Recommended shell alias:

```sh
alias token-usage='npx @lmoesle/token-usage-cli'
```

You can also install the CLI globally with npm or configure the widget base command to run `npx --yes @lmoesle/token-usage-cli` directly.

Plasma starts widgets outside a normal interactive terminal. It does not load aliases from `.bashrc`, so create a real `token-usage` executable in a directory on the GUI session `PATH`, or change the widget base command in its settings.

Example wrapper:

```sh
mkdir -p ~/.local/bin
printf '%s\n' '#!/usr/bin/env sh' 'export PATH="~/.nvm/versions/node/v24.16.0/bin:$PATH"' 'exec npx --yes @lmoesle/token-usage-cli "$@"' > ~/.local/bin/token-usage
chmod +x ~/.local/bin/token-usage
```

This wrapper avoids the `.bashrc` alias problem and exports the current nvm Node directory before running `npx`. This is needed because `npx` itself starts Node through `/usr/bin/env node`, and Plasma's `PATH` usually does not include nvm paths. If the Node version changes, update the path in `~/.local/bin/token-usage`.

The compact panel widget refreshes `token-usage today --raw` every 30 seconds and displays today's total cost as `$0.00 🔥`. Opening the widget shows Today, Weekly, Monthly, and Yearly tabs; selecting a tab runs that period's command again and displays the returned entries in a table.

## Structure

```txt
package/
├── metadata.json
└── contents
    ├── config
    │   ├── config.qml
    │   └── main.xml
    └── ui
        ├── configGeneral.qml
        └── main.qml
```

## Development

Test without installing from the repository root:

```sh
plasmoidviewer -a ./package -s 1100x520
```

Test as a horizontal panel widget:

```sh
plasmoidviewer -a ./package -l topedge -f horizontal -s 1100x520
```

Install or upgrade locally:

```sh
make install
```

Run the installed widget in a window:

```sh
plasmawindowed lmoesle-token-usage
```

Package for distribution:

```sh
make package
```
