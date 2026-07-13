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
   cp messages.conf.sample messages.conf
   ```

2. Edit `messages.conf` to customize the candle duration and messages:

   ```bash
   vi messages.conf
   ```

   `CANDLE_DURATION_MIN` must be a positive integer. Message values may be
   empty when an announcement is not needed.

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

Run it from the repository root so it can find `messages.conf`:

```bash
.build/release/candle-timer
```

Alternatively, place `messages.conf` in the same directory as the compiled
executable.

## Tests

Run the automated tests with:

```bash
swift test
```
