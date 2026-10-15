# Ash Ledger — 1.0 (beta)

By **Éuthanize** · Ebonhold · World of Warcraft **3.3.5a**

Tracks Soul Ash, saved ash, crates and raid lockouts across your characters.

## Download

[Download AshLedger.zip](https://github.com/PLs325-max/AshLedger/raw/refs/heads/main/AshLedger.zip)

## Installation

1. Close World of Warcraft and download the ZIP above.
2. Extract it into your Ebonhold game folder's `Interface/AddOns` folder.
3. Check that `Interface/AddOns/AshLedger/AshLedger.toc` exists. Avoid an extra nested folder.
4. Enable **Ash Ledger** in the character selection screen's **AddOns** menu.
5. Log in and type `/ashle` or click its minimap button.

When updating, replace the old addon folder and keep your **WTF** folder to retain saved records and settings.

## Features

- Character names and levels, with the logged-in character highlighted.
- Run Soul Ash, spendable Saved Ash, bag/bank crates and total available ash.
- Crate estimates of 400,000 or 800,000 with the bonus toggle.
- Combined total of fully funded 100-million-ash Infinite Nodes.
- Raid locks for Naxxramas, Obsidian Sanctum, Eye of Eternity, Ulduar and ICC, in 10/25-player modes; ICC heroic modes are separate.
- Observed Clear IDs reset cost and next known saved raid reset countdown.
- Current-character session Ash per hour, with a movable optional pop-out.
- Sortable columns, movable/resizable main window, movable minimap button and font settings.
- Standalone operation without an Altoholic/DataStore dependency.

## First use

Log in to each character you want recorded. Open Ebonhold's run/ash panel and skill tree, then click **Refresh** in Ash Ledger. Visit the bank to capture banked crates. Open the game's **Clear IDs** panel and Refresh to capture its reset cost.

Offline characters display their last recorded values. `--` means unknown and `*` marks a partial total. Ash Ledger reads visible currency panels; it cannot retrieve hidden server balances.

## Controls

Click **Soul Ash** or **Raid Locks** to switch views. Click a column heading to sort; click again to reverse. Drag the title bar to move the window and the bottom-right corner to resize. Use **Settings** to choose a font, text size and the Ash/h pop-out.

Raid labels: green **Ready**, red **Locked**, **Recheck** for expired saved timers that need a fresh check.

| Command | Action |
| --- | --- |
| `/ashle` | Open/close the ledger |
| `/ashle settings` | Open settings |
| `/ashle refresh` | Refresh visible balances and raid information |
| `/ashle rate` | Toggle the Ash/h pop-out |
| `/ashle rate reset` | Restart the rate calculation |
| `/ashle minimap` | Toggle the minimap button |
| `/ashle resetpos` | Restore main window position and size |

## Ash per hour

Ash/h is the current character's **net change in run + Saved Ash** during this login/reload session. First observations establish starting balances. Spending and losses lower the rate; crate estimates are excluded. Idle session time is included. Transfers cancel when both balances can be read. Balances refresh after combat or on Refresh; the visible rate text updates each second without extra recurring balance scans.

The pop-out stays visible when the ledger closes. Drag it to move it. Resetting the rate does not clear character records.

## Reporting problems

This is a **beta** release. [Open an issue](https://github.com/PLs325-max/AshLedger/issues) with what happened, what you expected, your client version and any exact Lua error. Screenshots are useful; remove personal details before posting.

The addon does not spend ash, open crates or reset raids. Validation uses simulated game events/UI; final behaviour depends on Ebonhold's live panels.
