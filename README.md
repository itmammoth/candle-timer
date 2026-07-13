# Candle Timer

A small macOS command-line utility written in Swift. It announces the time
remaining before each candle closes using the system speech synthesizer.

It can announce at:

- 60 seconds remaining
- 30 seconds remaining
- 10 seconds remaining
- 5 seconds remaining
- Candle close (one second before the boundary)

Empty messages are skipped.

## Requirements

- macOS 13 or later
- Swift 6 or later to build from source

The full Xcode application does not need to be open. Xcode Command Line Tools
are sufficient for building and running the command-line utility.

## Usage

1. Create a local configuration file:

   ```bash
   cp config.json.sample config.json
   ```

2. Edit `config.json` to customize the candle duration and speech rules:

   ```bash
   vi config.json
   ```

   Each rule separates its condition under `when` from its speech action under
   `speak`:

   ```json
   {
     "candle": {
       "durationMinutes": 5
     },
     "rules": [
       {
         "when": {
           "secondsBeforeClose": 45
         },
         "speak": {
           "message": "45 seconds remaining"
         }
       }
     ]
   }
   ```

   - `candle.durationMinutes` must be a positive integer.
   - `rules[].when.secondsBeforeClose` must be between 1 and the candle
     duration in seconds.
   - `rules[].speak.message` is the text to announce. Empty messages are
     skipped.

   The file must be valid JSON, so comments and trailing commas are not
   supported.

3. Build and run the timer:

   ```bash
   swift run candle-timer
   ```

The process continues running until you press `Ctrl+C`.

## Release build

Create an optimized executable with:

```bash
swift build -c release
```

Run it from the repository root so it can find `config.json`:

```bash
.build/release/candle-timer
```

Alternatively, place `config.json` in the same directory as the compiled
executable.

## Tests

Run the automated tests with:

```bash
swift test
```
