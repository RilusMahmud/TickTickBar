# Implementation notes

## Scope

- Keep the task composer fixed directly above the popover footer while task rows scroll.
- Make the Habits tab match `design-mockup.html`, including its header, calendar scale, rows, and tab-specific popover height.
- Rebuild and verify both tabs with runtime screenshots.

## Root cause

- `PopoverRoot` wraps each full tab in one `ScrollView`, so the task composer scrolls with the task rows.
- The shared 560 pt height cap is too short for the mockup's six-row month calendar plus habit rows.
- The title/count header lives inside `TasksView` and is absent from `HabitsView`, preventing the shared mockup structure.

## Plan

1. Move the title/count header into `PopoverRoot`.
2. Give each tab its own fixed presentation height.
3. Move task scrolling inside `TasksView`, outside the composer.
4. Give `HabitsView` its own bounded scrolling surface and align calendar/row styling with the mockup.
5. Build, package, launch, and capture both tabs.

## Deviations

- `make-app.sh` referenced `../ticktick.svg`, which would remove the existing app bundle and then fail during packaging. Corrected it to the repository-local `ticktick.svg` before rebuilding.
