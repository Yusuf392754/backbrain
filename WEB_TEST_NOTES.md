# Web smoke test notes

The Vercel-compatible web entry point was served locally over HTTP at `http://localhost:4173/`.

The home screen loaded successfully with no browser-console output. Submitting `who is sarah?` through the ask bar rendered the expected answer, and the input reset after the interaction. The initial runtime path therefore works under HTTP rather than only from a `file://` URL.

Remaining checks cover persistence after reload, scheduling inbox actions, calendar create/delete, people create/edit/delete, settings toggles, and the reset path.

The scheduling inbox flow also passed locally: a reminder was added, the confirm modal accepted a date, the inbox count decreased, and the item appeared in the calendar. Deleting that calendar event returned the selected day to `nothing scheduled.`.

The earlier version did not persist inbox, event, people, settings, or subscription state. The current edit adds a versioned `backbrain_state_v1` localStorage snapshot and resets all mutable demo state coherently.

The people flow passed: a temporary contact was created and remained visible after a reload. Settings toggles changed immediately and restored their values after reload. The mock subscription rejected an invalid email, accepted a valid email, showed the subscribed state, and returned to the plan after cancellation. Reset restored the sample inbox, default people, default toggle values, and cleared test history; the final clean reload rendered the sample home screen without console errors.

Feature-pass notes: the home screen now exposes `start listening` and a disabled `listening is off`/turn-off control; the You tab renders a central `you` node with memories, friends, passwords, health, and schedule nodes. Selecting `passwords` shows a deliberate warning that real credentials must not be stored in the static prototype.

The voice router was exercised directly with `add event dentist appointment`, and the event rendered in the calendar. The browser microphone itself returned `not-allowed` in the sandbox because microphone permission is unavailable; production voice recognition requires HTTPS and user-granted microphone access. The explicit stop path is implemented for browsers where recognition starts successfully.

The updated settings screen now shows the security center and explicitly states that static mode has no server sign-in or true E2EE. The voice command `show passwords` was routed directly and opened the You map on the passwords node as expected.

Customizable-map pass: the You workspace now renders a perspective grid, depth markers, connectors, draggable topic nodes, and map tools for add node, reset layout, edit selected, and remove selected. A temporary `projects` node was created with a custom description and light-blue color, selected, and rendered in the map. The theme switch changed the app to dark mode, and the dark theme persisted after reload while the home flow continued to render.

The custom-node drag path was exercised against the real map geometry: the `projects` node moved to approximately 34% horizontal and 42% vertical position, and the updated coordinates were saved through the normal state layer.
