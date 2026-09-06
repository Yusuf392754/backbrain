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

True 3D graph pass: the You map now renders on a Canvas as a depth-projected spatial graph with a glowing blue You node, dashed connections, depth labels, and perspective movement. The canvas handlers were exercised for orbit rotation, shift-drag panning, and wheel zoom; all three camera properties changed as expected. The graph supports node dragging, selection, double-click editing, automatic orbit pause/resume, reset view, and persisted node positions. This is a browser-native 3D projection without an external runtime dependency, so it remains static-hosting compatible.

Topic-card and auto-graph pass: selecting a topic opens a modal card with the topic description, activity items, add-detail, customize, remove-node, close, and done actions. Automatic topic updates are persisted as a user setting. A fresh uncategorized question created a new `what should I` node and added the full question as an automatic content item; existing schedule/friends/health activity routes into their matching topic nodes. New custom details are saved as manual items.

Final card-content pass: an automatically generated topic node opened a topic card successfully. A manual detail was added to that node and persisted in its item list alongside the automatic question item. Navigation now closes open topic cards cleanly so they cannot obstruct home, calendar, people, settings, or voice controls.
