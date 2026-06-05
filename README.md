# token-usage-kde-widget

KDE Plasma 6 widget for displaying output from the `token-usage` CLI.

The widget package id and display name are `lmoesle-token-usage`.

## CLI contract

The widget runs this command by default:

```sh
token-usage
```

Recommended shell alias:

```sh
alias token-usage='npx @lmoesle/token-usage-cli'
```

You can also install the CLI globally with npm or configure the widget command to run `npx --yes @lmoesle/token-usage-cli` directly.

Plasma starts widgets outside a normal interactive terminal. If your shell alias is not visible to Plasma, create a `token-usage` executable in a directory on the GUI session `PATH`, or change the widget command in its settings.

Example wrapper:

```sh
mkdir -p ~/.local/bin
printf '#!/usr/bin/env sh\nexec npx --yes @lmoesle/token-usage-cli "$@"\n' > ~/.local/bin/token-usage
chmod +x ~/.local/bin/token-usage
```

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
plasmoidviewer -a ./package
```

Test as a horizontal panel widget:

```sh
plasmoidviewer -a ./package -l topedge -f horizontal
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
