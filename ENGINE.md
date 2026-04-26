# SPEC: External Android Stockfish via OEX for Flutter

## Objective

Replace the bundled Stockfish Flutter package with support for an externally installed Android chess engine app using the Open Exchange / OEX engine interface.

The app must not bundle Stockfish binaries.

The app must not execute Stockfish from arbitrary filesystem paths.

## Non-Goals

- Do not execute binaries from `/storage`, `Downloads`, or arbitrary user-selected paths.
- Do not bundle Stockfish binaries in the APK or AAB.
- Do not use the `stockfish` Flutter package.
- Do not implement a chess engine.
- Do not redesign unrelated chess UI.
- Do not refactor unrelated game logic.

## Target Behavior

The Flutter app must:

1. Detect installed compatible external chess engine apps.
1. Show the user the available engines.
1. Let the user select one engine.
1. Persist the selected engine package name.
1. Connect to the selected engine through Android native code.
1. Communicate with the engine using UCI commands.
1. Stream engine output back to Dart.
1. Reuse the existing UCI parsing logic where possible.
1. Preserve the existing analysis UI behavior.

## Architecture

```text
Flutter / Dart chess app
  |
  | MethodChannel / EventChannel
  v
Android Kotlin OEX bridge
  |
  | Android Intent / Service binding
  v
External chess engine APK
  |
  | UCI protocol
  v
Stockfish engine
```

## Dart API

Create or adapt this abstraction:

```dart
abstract class ChessEngine {
  Future<List<ExternalChessEngine>> listEngines();
  Future<void> start(String packageName);
  Future<void> send(String command);
  Stream<String> get output;
  Future<void> stop();
}
```

Create this model:

```dart
class ExternalChessEngine {
  final String name;
  final String packageName;

  const ExternalChessEngine({
    required this.name,
    required this.packageName,
  });

  factory ExternalChessEngine.fromMap(Map<dynamic, dynamic> map) {
    return ExternalChessEngine(
      name: map['name'] as String,
      packageName: map['packageName'] as String,
    );
  }

  Map<String, String> toMap() {
    return {
      'name': name,
      'packageName': packageName,
    };
  }
}
```

Implement the Android-backed engine:

```dart
import 'package:flutter/services.dart';

class OexChessEngine implements ChessEngine {
  static const MethodChannel _method = MethodChannel('app/oex_engine');
  static const EventChannel _events = EventChannel('app/oex_engine_output');

  @override
  Stream<String> get output => _events.receiveBroadcastStream().cast<String>();

  @override
  Future<List<ExternalChessEngine>> listEngines() async {
    final result = await _method.invokeMethod<List<dynamic>>('listEngines');

    return (result ?? [])
        .map((item) => ExternalChessEngine.fromMap(item as Map<dynamic, dynamic>))
        .toList();
  }

  @override
  Future<void> start(String packageName) {
    return _method.invokeMethod('start', {
      'packageName': packageName,
    });
  }

  @override
  Future<void> send(String command) {
    return _method.invokeMethod('send', {
      'command': command,
    });
  }

  @override
  Future<void> stop() {
    return _method.invokeMethod('stop');
  }
}
```

## Flutter Channels

Use this method channel:

```text
app/oex_engine
```

Use this event channel:

```text
app/oex_engine_output
```

## MethodChannel Contract

| Method | Arguments | Return |
|---|---|---|
| `listEngines` | none | `List<Map<String, String>>` |
| `start` | `{ packageName: String }` | void |
| `send` | `{ command: String }` | void |
| `stop` | none | void |

## EventChannel Contract

The EventChannel emits one string per UCI output line:

```text
String
```

Example emitted values:

```text
info depth 12 score cp 34 pv e2e4 e7e5 g1f3
info depth 15 score mate 3 pv h5f7
bestmove e2e4 ponder e7e5
```

## Android Manifest

Add Android package visibility for Android 11+:

```xml
<queries>
    <intent>
        <action android:name="intent.chess.provider.ENGINE" />
    </intent>
</queries>
```

## Android Native Implementation

Implement the Android bridge in Kotlin.

The bridge must:

1. Register the `app/oex_engine` MethodChannel.
1. Register the `app/oex_engine_output` EventChannel.
1. Implement engine discovery.
1. Implement service binding to the selected engine.
1. Implement command sending.
1. Forward engine output lines to Flutter.
1. Clean up correctly on stop or activity destruction.

## Engine Discovery

Use the OEX engine intent action:

```text
intent.chess.provider.ENGINE
```

Kotlin discovery logic:

```kotlin
val intent = Intent("intent.chess.provider.ENGINE")
val services = packageManager.queryIntentServices(intent, 0)
```

For each result:

- read the display label as `name`
- read the package name as `packageName`
- optionally retain the service class name internally if needed for binding

Return to Dart:

```json
[
  {
    "name": "Stockfish",
    "packageName": "example.stockfish.package"
  }
]
```

## Engine Selection

The Flutter app must persist the selected engine package name.

On app startup:

1. Read the saved package name.
1. Run engine discovery.
1. Verify that the saved package is still available.
1. If unavailable, clear the saved package name and ask the user to select an engine again.

## Engine Lifecycle

### start(packageName)

Native Android must:

1. Create an intent with action `intent.chess.provider.ENGINE`.
1. Restrict it to the selected `packageName`.
1. Bind to the matching engine service.
1. Open the engine communication channel.
1. Start reading engine output.
1. Forward each output line through `app/oex_engine_output`.
1. Run UCI initialization.

### send(command)

Native Android must:

1. Validate that an engine is connected.
1. Write the command string to the engine.
1. Append a newline if required by the engine communication interface.
1. Not crash on invalid or empty commands.

### stop()

Native Android must:

1. Send `quit` if the engine is connected.
1. Close input/output streams or equivalent communication handles.
1. Unbind the service.
1. Clear internal state.
1. Stop emitting output events.

## UCI Initialization Flow

After the engine connection is established, send:

```text
uci
```

Wait for:

```text
uciok
```

Then send:

```text
isready
```

Wait for:

```text
readyok
```

Only after this sequence is complete should the engine be considered ready for analysis.

## UCI New Game Flow

Before analyzing a new game, send:

```text
ucinewgame
isready
```

Wait for:

```text
readyok
```

## UCI Position Flow

For FEN-based analysis:

```text
position fen <FEN>
```

For move-list based analysis, if the existing app already uses it:

```text
position startpos moves <MOVE_1> <MOVE_2> ...
```

## UCI Analysis Flow

Use the same analysis mode the app currently uses.

For fixed depth:

```text
go depth <N>
```

For fixed time:

```text
go movetime <MS>
```

For infinite analysis:

```text
go infinite
```

## UCI Stop Flow

To stop analysis:

```text
stop
```

Wait for a `bestmove` line where appropriate.

## UCI Shutdown Flow

To shut down the engine:

```text
quit
```

## Required Output Handling

The Dart side must continue to parse standard UCI output.

Relevant examples:

```text
info depth 12 seldepth 18 multipv 1 score cp 34 pv e2e4 e7e5 g1f3
info depth 15 score mate 3 pv h5f7
bestmove e2e4 ponder e7e5
```

Required parser behavior:

- parse centipawn scores
- parse mate scores
- parse best move
- parse principal variation
- ignore unknown UCI tokens safely
- do not crash on malformed lines

Reuse existing UCI parsing logic where possible.

## Error Handling

| Case | Required Behavior |
|---|---|
| No compatible engine installed | Show `No compatible external chess engines found` |
| No engine selected | Show `No external chess engine selected` |
| Selected engine was uninstalled | Clear saved selection and ask user to select again |
| Engine service binding fails | Show connection error |
| Engine disconnects | Stop analysis and show engine disconnected state |
| `uciok` timeout | Stop engine and show timeout error |
| `readyok` timeout | Stop engine and show timeout error |
| Invalid command | Do not crash |
| Activity recreated | Reset or reconnect cleanly |
| App closed | Stop engine and release resources |

## Timeouts

Use these defaults:

| Operation | Timeout |
|---|---:|
| Service bind | 5 seconds |
| Wait for `uciok` | 5 seconds |
| Wait for `readyok` | 5 seconds |

On timeout:

1. Stop the current engine session.
1. Emit an error state to Flutter.
1. Allow the user to retry.

## UI Requirements

Add or adapt an engine settings screen.

The screen must contain:

- title: `Chess engine`
- list of discovered compatible engines
- selected engine indicator
- refresh action
- empty state if no compatible engine exists

Required empty states:

```text
No external chess engine selected
```

```text
No compatible external chess engines found
```

Do not redesign the analysis screen unless strictly required.

## Android Lifecycle

On activity destroy:

1. Stop active analysis.
1. Send `quit` if connected.
1. Unbind from the engine service.
1. Release streams/listeners.
1. Clear event sink references.

On app background:

- stop infinite analysis unless the existing app intentionally supports background analysis

On app foreground:

- validate that the selected engine is still installed before starting analysis

## Migration Requirements

Remove:

- `stockfish` Flutter package dependency
- imports from the `stockfish` package
- direct construction of the old Stockfish engine object
- bundled Stockfish binary assumptions

Replace with:

- `ChessEngine` abstraction
- `OexChessEngine` implementation
- Android OEX bridge
- external engine selection UI

Existing features must continue to work:

- start analysis
- stop analysis
- show best move
- show evaluation
- show principal variation
- handle mate scores
- handle centipawn scores

## Testing Requirements

### Dart Tests

Add tests for:

1. `ExternalChessEngine.fromMap`
1. engine list mapping
1. UCI `info` parsing with centipawn score
1. UCI `info` parsing with mate score
1. UCI `bestmove` parsing
1. missing engine selected state
1. selected engine removed state
1. malformed UCI output line handling

### Android Manual Tests

Test case 1:

1. Install the Flutter app.
1. Do not install any external chess engine.
1. Open engine settings.
1. Verify `No compatible external chess engines found`.

Test case 2:

1. Install an OEX-compatible Stockfish engine app.
1. Open engine settings.
1. Verify that the engine appears.
1. Select the engine.
1. Close and reopen the app.
1. Verify that the selection persists.

Test case 3:

1. Select an external engine.
1. Start analysis.
1. Verify that the app sends `uci`.
1. Verify that the app receives `uciok`.
1. Verify that the app sends `isready`.
1. Verify that the app receives `readyok`.
1. Verify that analysis output is displayed.

Test case 4:

1. Start analysis.
1. Stop analysis.
1. Verify that `stop` is sent.
1. Verify that the app remains usable.

Test case 5:

1. Select an engine.
1. Uninstall the engine.
1. Reopen the app.
1. Verify that the saved selection is cleared or reported invalid.
1. Verify that the app does not crash.

## Implementation Constraints

- Make minimal targeted changes.
- Reuse existing UCI parser.
- Reuse existing analysis state where possible.
- Keep Android-specific OEX code isolated under Android.
- Do not add a new bundled engine dependency.
- Do not bundle Stockfish.
- Do not execute arbitrary filesystem binaries.
- Do not refactor unrelated UI.
- Do not change unrelated game logic.

## Acceptance Criteria

The implementation is complete when:

1. The `stockfish` Flutter package dependency is removed.
1. The APK/AAB no longer contains bundled Stockfish binaries.
1. The app discovers installed OEX-compatible chess engines.
1. The user can select an external engine.
1. The app persists the selected engine.
1. The app validates that the selected engine is still installed.
1. The app connects to the selected engine.
1. The app sends UCI commands to the selected engine.
1. The app receives UCI output from the selected engine.
1. The existing analysis UI displays engine output correctly.
1. Missing-engine cases do not crash the app.
1. Uninstalled-engine cases do not crash the app.
1. The app does not execute binaries from arbitrary filesystem paths.
