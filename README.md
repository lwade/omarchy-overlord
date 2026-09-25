# Overlord

Overlord is an Omarchy shell plugin that provides local notes and task tracking. It is based on the Eisenhower Matrix (https://en.wikipedia.org/wiki/Time_management#Eisenhower_method). 

The Eisenhower Matrix is a productivity, prioritization, and time-management tool designed to help you prioritize a list of tasks by categorizing them according to their urgency and importance. The name was coined by Stephen Covey, the author of The 7 Habits of Highly Effective People, who took inspiration from a speech given by Dwight D. "Ike" Eisenhower, the 34th President of the United States. Eisenhower quoted an unknown university president during a speech, stating, “I have two kinds of problems: the urgent, and the unimportant. The urgent are not important, and
the important are never urgent.” 
source: https://sps.columbia.edu/sites/default/files/2023-08/Eisenhower%20Matrix.pdf 

Also sometimes called an Eisenhower Decision Matrix, Eisenhower Box, or Urgent-Important Matrix.

## Usage

Click the star. The board opens under the icon, the same way other bar plugins do. 

![The star in the bar](docs/bar.png)

Add a note and it lands in Do to begin with.

[Add a note](docs/add-note.mp4)

Drag it to Schedule, Delegate, or Eliminate, according to the Eisenhower method and to apply a classification to the task.

[Drag a note](docs/drag-note.mp4)

Eliminate will delete immediately unless Confirm is toggled on.

[Confirm delete](docs/confirm-delete.mp4)

Delegate drops it after 24 hours.

[Delegate](docs/delegate.mp4)

Simple hides Delegate and Eliminate and offers up a basic 2-pane task categorisation view.

[Simple mode](docs/simple-mode.mp4)

Search filters the cards in place. Each pane shows about 10 notes before it starts scrolling. To configure the storage location for your notes, click the settings icon:

[Notes folder](docs/notes-folder.mp4)

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

## Notes

Notes, the Simple and Confirm Delete toggles, and the counters are one file:

```text
$XDG_DATA_HOME/omarchy-overlord/overlord.json
```

If `XDG_DATA_HOME` is unset, that is `~/.local/share/omarchy-overlord/overlord.json`.

Copy that file to back the board up. On another machine, install the plugin, put the file at the same path, then run `omarchy restart shell`. A replaced file is not picked up until the shell restarts.

The folder button on the board can point the notes at another folder, such as a directory mounted from cloud storage. The file name stays `overlord.json`. Notes already in the old folder stay there until you copy them. An older `board.json` in the chosen folder is read once and saved as `overlord.json`.

## Config

The Simple and Confirm Delete toggles live in `overlord.json` with the notes.

The notes folder is a separate setting, `notesDir`, stored with the bar widget in `~/.config/omarchy/shell.json`. Empty means the default path above. That setting is not inside the notes file, so the plugin can still find `overlord.json` after you move it.

Which bar section the star sits in is Omarchy's own config, `~/.config/omarchy/shell.json`. That file is not the board. The installed plugin under `~/.config/omarchy/plugins/io.github.lwade.overlord` is the program, not your notes.

## Remove

```sh
omarchy plugin remove io.github.lwade.overlord
```

The board file is left in place.
