ASH LEDGER - 1.0 (beta)
By Éuthanize
For Ebonhold / World of Warcraft 3.3.5a

WHAT IT DOES
- Shows Soul Ash, crates and total available ash across your characters.
- Includes spendable Saved Ash from the skill tree in the total.
- Values crates at 400,000 ash, or 800,000 with the +100% option.
- Shows how many full 100-million-ash Infinite Nodes your combined total funds.
- Tracks 10/25-player raid locks for Naxxramas, Obsidian Sanctum,
  Eye of Eternity, Ulduar and ICC, including ICC heroic modes.
- Shows observed raid reset costs and the next known raid reset countdown.
- Shows this character's session Ash per hour, with an optional movable pop-out.
- Works independently of Altoholic.

INSTALL OR UPDATE
1. Close World of Warcraft.
2. Open the folder containing your Ebonhold WoW.exe.
3. Extract the ZIP and copy its AshLedger folder into:
   Interface\AddOns
   The final layout must be:
   Interface\AddOns\AshLedger\AshLedger.toc
   Do not put it inside an extra AshLedger folder.
4. At character selection, click AddOns and enable Ash Ledger.
5. Log in and type /ashle, or click the Ash Ledger minimap button.

Updating? Replace the old AshLedger addon folder. Keep your WTF folder;
your saved character balances, settings and raid records are kept there.

FIRST USE
1. Log in to each character you want listed.
2. Open Ebonhold's run/ash panel and skill tree, then click Refresh in
   Ash Ledger to capture run ash and Saved Ash.
3. Visit the bank once to include banked crates.
4. Open the game's Clear IDs panel and Refresh to capture its reset cost.
5. Repeat on your other characters. Offline characters show their last
   recorded values, not a live server balance.

USING THE WINDOW
- Soul Ash tab: balances, crates, total available and reset costs.
- Raid Locks tab: Ready is green; Locked is red. Recheck means an old raid
  timer has expired and the character needs a fresh check.
- Click a column heading to sort. Click again to reverse the order.
- Drag the title bar to move the window; drag the bottom-right to resize.
- Drag the minimap button to reposition it.
- Settings lets you change font and size and toggle the Ash/h pop-out.
- The crate bonus button switches between 400,000 and 800,000 per crate.

ASH PER HOUR
Ash/h measures this character's net change in run + Saved Ash during the
current login/reload session. Spending or losing ash lowers the rate.
Crate estimates are excluded. Idle time is included.
The first live reading of each balance establishes its starting point.
Keep the relevant balances visible when refreshing; transfers cancel when
both balances can be read. Balances update after combat or on Refresh.
The pop-out stays visible when the main ledger is closed. Drag it to move.
Reset rate starts a new rate calculation without clearing character data.

USEFUL COMMANDS
/ashle              Open or close Ash Ledger
/ashle settings     Open Settings
/ashle refresh      Refresh visible balances and raid information
/ashle rate         Show or hide the Ash/h pop-out
/ashle rate reset   Restart this session's Ash/h calculation
/ashle minimap      Show or hide the minimap button
/ashle resetpos     Restore the main window's position and size

IF SOMETHING IS MISSING
-- means a value has not been recorded. An asterisk (*) marks partial totals.
Open the relevant Ebonhold panel and click Refresh. Visit the bank for
banked crates, and log in to each character to update its saved record.
Ash Ledger reads visible game panels; hidden balances cannot be queried.
It never spends ash, opens crates or resets raids for you.

This is a beta release. Report any issues with what you were doing and,
if possible, the exact Lua error or a screenshot.
