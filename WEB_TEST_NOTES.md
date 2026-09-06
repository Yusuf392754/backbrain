# Web smoke test notes

The Vercel-compatible web entry point was served locally over HTTP at `http://localhost:4173/`.

The home screen loaded successfully with no browser-console output. Submitting `who is sarah?` through the ask bar rendered the expected answer, and the input reset after the interaction. The initial runtime path therefore works under HTTP rather than only from a `file://` URL.

Remaining checks cover persistence after reload, scheduling inbox actions, calendar create/delete, people create/edit/delete, settings toggles, and the reset path.

The scheduling inbox flow also passed locally: a reminder was added, the confirm modal accepted a date, the inbox count decreased, and the item appeared in the calendar. Deleting that calendar event returned the selected day to `nothing scheduled.`.

The earlier version did not persist inbox, event, people, settings, or subscription state. The current edit adds a versioned `backbrain_state_v1` localStorage snapshot and resets all mutable demo state coherently.

The people flow passed: a temporary contact was created and remained visible after a reload. Settings toggles changed immediately and restored their values after reload. The mock subscription rejected an invalid email, accepted a valid email, showed the subscribed state, and returned to the plan after cancellation. Reset restored the sample inbox, default people, default toggle values, and cleared test history; the final clean reload rendered the sample home screen without console errors.
