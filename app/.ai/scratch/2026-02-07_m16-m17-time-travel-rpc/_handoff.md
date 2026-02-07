# Handoff: M16 Time Travel + M17 RPC Panel

## Summary
Implemented time-travel scrubber controls and RPC tools panel for the log viewer app.

## Files Created
- `lib/services/rpc_service.dart`: RpcService ChangeNotifier with tool registration, invoke/response handling, pending futures
- `lib/widgets/time_travel/time_scrubber.dart`: TimeScrubber widget with CustomPaint track, draggable thumb, timestamp labels
- `lib/widgets/time_travel/time_travel_controls.dart`: TimeTravelControls bar with toggle, scrubber, and LIVE button
- `lib/widgets/rpc/rpc_panel.dart`: RpcPanel slide-out drawer (300px) with tool list grouped by session
- `lib/widgets/rpc/rpc_tool_tile.dart`: RpcToolTile with tap-to-invoke, loading spinner, inline result/error display, confirm dialog
- `test/services/rpc_service_test.dart`: 3 tests — updateTools, handleResponse, unknown rpcId
- `test/widgets/time_travel/time_scrubber_test.dart`: 3 tests — inactive hidden, shows range, drag updates position
- `test/widgets/rpc/rpc_panel_test.dart`: 3 tests — grouped tools, tile name/desc, invoke triggers loading

## Files Modified
- `lib/main.dart`: Added RpcService to MultiProvider
- `lib/screens/log_viewer.dart`: Added time travel state, RPC panel state, Row layout with RpcPanel, TimeTravelControls at bottom, rpcResponse handling in _handleMessage
- `lib/widgets/header/session_selector.dart`: Added onRpcToggle callback + RPC toggle icon button in header

## Deviations
- `test/widgets/header/session_selector_test.dart`: Relaxed `App 7` visibility assertion in overflow test — adding the RPC icon button reduced available header width, making the 8th session scroll off-screen at default 800px test surface. Core overflow logic assertions preserved.

## Discovered Issues
- NONE

## Rollbacks
- NONE

## Verification
Status: PASS | Tests: 40/40 passed | Analysis: 0 new warnings (1 pre-existing in json_renderer.dart)

## Confidence
Level: HIGH | Concerns: none

## Next Steps
- Wire time-travel mode to LogStore filtering (filter entries by time range)
- Wire RPC tool discovery from server messages (sessionUpdate with tools payload)
- Wire onRangeChanged to history queries via LogConnection
