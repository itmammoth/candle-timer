# Candle Timer

A simple shell script that announces time remaining before a 5-minute candle close.
It notifies you by voice at:
- 10 seconds remaining
- 5 seconds remaining
- Candle close (at 4:59)

## Usage

1. Copy the sample configuration file.
   **REQUIRED**: The script will exit with an error if `messages.conf` is missing.

   ```bash
   cp messages.conf.sample messages.conf
   ```

2. Edit `messages.conf` to customize the voice messages and candle duration.

   ```bash
   vi messages.conf
   ```

   You can set `CANDLE_DURATION_MIN` (default in sample: 5) to change the candle interval (e.g., 3 for 3-minute candles).

3. Run the timer.

   ```bash
   ./candle-timer.sh
   ```

   The script runs in an infinite loop. Press `Ctrl+C` to stop.
