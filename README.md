# Overlord

Local Eisenhower board for notes and tasks. Runs inside the Omarchy shell. Nothing leaves the machine.

Click the star. The board opens under the icon, the same way other bar plugins do. Add a note and it lands in Do. Drag it to Schedule, Delegate, or Eliminate. Eliminate asks first while Confirm is on. Delegate drops it after 24 hours. Simple hides Delegate and Eliminate. Search filters the cards in place. Each pane shows about 10 notes before it scrolls.

## Install

```sh
omarchy plugin add https://github.com/lwade/omarchy-overlord.git --enable
```

## Develop

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

## Remove

```sh
omarchy plugin remove io.github.lwade.overlord
```

The board file is left in place.
