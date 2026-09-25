# Visual pass

`scripts/test` covers the board file and the star. This list is the live panel. Run `scripts/load-fixture`, open Overlord, then `scripts/restore-board` when finished. The fixture is not watched; the script restarts the shell so it loads.

After load, "stale handoff" is gone. That flush counts as Eliminate.

## Board

1. The star in the bar opens the board under the icon, not a centered overlay. Clicking it again closes it.
2. The header star is a circle with a star, not a soft blob. Same for the bar icon.
3. Title is Overlord. The strapline reads ACTION THIS DAY.
4. Chips read `3 Do`, `12 Schedule`, and `2 Delegate`. There is no Eliminate chip.
5. The line under the header is `4 Done · 2 Scheduled · 3 Delegated · 2 Eliminated`. The quadrant titles stay Do, Schedule, Delegate, and Eliminate.
6. Search and Add are the same height.
7. Do, Schedule, Delegate, and Eliminate are all on the panel. The right column is not clipped. The gap under the boxes matches the gap between them.
8. Do shows three notes. The long title is one elided line. "First line is the card" does not show the second line.
9. Schedule shows about 10 rows and scrolls to `scroll 12`. Do is the same height as Schedule. Delegate and Eliminate stay at about 5 rows.
10. Delegate notes are dim and italic. `clears 24h` sits on the same line as DELEGATE.
11. Search `scroll` leaves only the Schedule notes. Search `ASK` leaves Ask Sam and Ask Riley. Clearing the search restores the board. Escape clears the search before it closes the panel.
12. Add creates a note in Do. The new card does not stick to the cursor. `+` on Schedule creates the note there, not in Do. Neither changes the handled line.
13. Do notes have an empty tick on the left. The tip says Done. Clicking it removes the note with no dialog. The Do chip drops by one. The handled Do count goes up by one.
14. Schedule notes have the same tick. The tip says Scheduled. Clicking it removes the note and the handled Schedule count goes up by one. Delegate and Eliminate notes have no tick.
15. Drag a Do note onto Schedule. A ghost follows the pointer, and the note lands in Schedule. Releasing outside a box leaves it where it was. The handled line does not change.
16. Drag a note onto Eliminate. Confirm Delete? asks. Cancel keeps the note. Confirm removes it. The handled Eliminate count goes up by one. The chip counts do not.
17. Turn Confirm Delete? off. A drag onto Eliminate removes the note with no dialog. Turn it back on.
18. Simple hides Delegate and Eliminate and shows a delete mark on each note. The tick stays on Do and Schedule. Simple off hides the mark. The labels read Simple and Confirm Delete?, not capitals.
19. Open a note, clear the text, and press Done. With Confirm Delete? on, it asks before the note disappears.
20. Both toggles survive `omarchy restart shell`.

## File

The board file is `$XDG_DATA_HOME/omarchy-overlord/board.json`, or `~/.local/share/omarchy-overlord/board.json`. Copy that file to back it up or move it. A hand edit is not picked up until the shell restarts.
