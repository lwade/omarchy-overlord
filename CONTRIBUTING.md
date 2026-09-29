# Contributing

Edit this clone, then copy it into the shell plugin directory. The shell rejects symlinks inside a plugin folder.

```sh
scripts/install-dev
omarchy plugin enable io.github.lwade.overlord --section right
```

`keepLoaded` is set, so a change to `Service.qml` needs `omarchy restart shell`. Overlay and bar widget files reload on save after `scripts/install-dev`.

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Service.qml Panel.qml BarWidget.qml NoteCard.qml Star.qml
scripts/test
```
