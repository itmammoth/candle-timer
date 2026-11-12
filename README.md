# Candle Timer

A small macOS command-line utility written in Swift. It uses the system speech
synthesizer to announce candle timing according to time-of-day periods.

Each period can use a different candle duration and announce at:

- 60 seconds remaining
- 30 seconds remaining
- 10 seconds remaining
- 5 seconds remaining
- The exact candle close
- The start of a configured period

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

2. Edit `config.json` to customize the time periods, candle durations, and
   speech rules:

   ```bash
   vi config.json
   ```

   Each period has its own candle duration and rules. Each rule separates its
   condition under `when` from its speech action under `speak`:

   ```json
   {
     "timeZone": "Asia/Tokyo",
     "fallback": {
       "intervalMinutes": 15,
       "speak": {
         "message": "Market is closed"
       }
     },
     "periods": [
       {
         "start": "09:00",
         "end": "15:30",
         "candle": {
           "durationMinutes": 3
         },
         "rules": [
           {
             "when": {
               "secondsBeforeClose": 10
             },
             "speak": {
               "message": "10 seconds remaining"
             }
           },
           {
             "when": {
               "candleClosed": true
             },
             "speak": {
               "message": "Candle closed"
             }
           }
         ]
       }
     ]
   }
   ```

   - `timeZone` must be a valid IANA time zone identifier, such as
     `Asia/Tokyo`.
   - Optional `fallback` speech applies whenever the current time is outside
     every configured period. `intervalMinutes` must be a positive integer.
     If the timer launches outside all periods, it speaks immediately. Subsequent
     announcements follow clock times measured from 00:00 in `timeZone`, rather
     than elapsed time since launch. For example, `15` announces at minute 00,
     15, 30, and 45 of every hour; launching at 07:04 speaks immediately and next
     at 07:15. Other intervals also use 00:00 as their daily origin: `90` means
     00:00, 01:30, 03:00, and so on, resetting at midnight.
   - `periods` must be in ascending order and must not overlap. Gaps are
     allowed. They use `fallback` speech when configured and otherwise remain
     silent.
   - `start` and `end` use `HH:mm` format. Overnight periods are not supported.
   - Each period must be evenly divisible by its positive
     `candle.durationMinutes` value.
   - Each `rules[].when` must contain exactly one condition:
     - `secondsBeforeClose` announces before every candle close and must be
       between 1 and the candle duration in seconds.
     - `candleClosed: true` announces at the exact candle close, including the
       end of the period.
     - `periodStarted: true` announces once when the period starts.
   - `rules[].speak.message` is the text to announce. Empty messages are
     skipped.

   When one period ends exactly as another starts, candle-close messages from
   the ending period are spoken before period-start messages from the new
   period. When the final period ends with a regular announcement, fallback
   speech starts at the next scheduled clock time. Without a regular announcement,
   entering a gap or ending the final period speaks fallback immediately, then
   follows the same clock times. The schedule is applied every day, including
   weekends. Missed announcements during sleep or downtime are not replayed.
   When the timer remains outside periods across sleep, resuming does not
   trigger an overdue announcement. A new launch outside periods still speaks
   immediately.

   The file must be valid JSON, so comments and trailing commas are not
   supported.

   Earlier versions used top-level `candle` and `rules` values. That format is
   no longer supported; replace it with `timeZone` and `periods` as shown above.

3. Build and run the timer:

   ```bash
   swift run candle-timer
   ```

The process continues running until you press `Ctrl+C`.

To compensate for the short delay before macOS starts playing speech, scheduled
announcements are submitted to the speech synthesizer one second before their
configured time. This applies consistently to candle countdowns, candle closes,
period starts, scheduled fallback announcements, and the transition to fallback
speech.

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
