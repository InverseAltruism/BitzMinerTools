#!/bin/bash

LOGFILE="$HOME/bitzminer.log"
CORE_COUNT=8
RPC_PRIMARY="https://mainnetbeta-rpc.eclipse.xyz/"
RPC_BACKUP="https://bitz-000.eclipserpc.xyz/"
RETRY_DELAY=30
CLAIM_INTERVAL=1800  # 30 minutes
CRASH_COUNT=0
CURRENT_RPC="$RPC_PRIMARY"
LAST_CLAIM_TIME=$(date +%s)

function rotate_rpc() {
  if [ "$CURRENT_RPC" == "$RPC_PRIMARY" ]; then
    CURRENT_RPC="$RPC_BACKUP"
  else
    CURRENT_RPC="$RPC_PRIMARY"
  fi
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Switched RPC to: $CURRENT_RPC" | tee -a "$LOGFILE"
  solana config set --url "$CURRENT_RPC" > /dev/null
}

function restart_script() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - [RESTART] Too many crashes. Restarting full script cleanly..." | tee -a "$LOGFILE"
  exec "$0"
}

function track_rewards() {
  TOTAL=$(grep -oP '[0-9]+\.[0-9]{8}' "$LOGFILE" | paste -sd+ - | bc 2>/dev/null)
  LAST24H=$(grep "$(date -d '24 hours ago' '+%Y-%m-%d')" "$LOGFILE" | grep -oP '[0-9]+\.[0-9]{8}' | paste -sd+ - | bc 2>/dev/null)
  echo "BITZ mined last 24H: ${LAST24H:-0}" | tee -a "$LOGFILE"
  echo "BITZ mined Total: ${TOTAL:-0}" | tee -a "$LOGFILE"
}

mkdir -p "$(dirname $LOGFILE)"
echo "====== Bitz Miner STARTED at $(date) ======" | tee -a "$LOGFILE"
solana config set --url "$CURRENT_RPC" > /dev/null

while true; do
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting Bitz Miner with $CORE_COUNT cores..." | tee -a "$LOGFILE"

  bitz collect --cores "$CORE_COUNT" 2>&1 | tee -a "$LOGFILE"
  EXIT_CODE=${PIPESTATUS[0]}
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Miner exited with code $EXIT_CODE" | tee -a "$LOGFILE"

  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - LAST_CLAIM_TIME))
  if [ "$ELAPSED" -ge "$CLAIM_INTERVAL" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Auto-claiming rewards..." | tee -a "$LOGFILE"
    yes | bitz claim 2>&1 | tee -a "$LOGFILE"
    LAST_CLAIM_TIME=$CURRENT_TIME
    track_rewards
  fi

  if tail -n 50 "$LOGFILE" | grep -q "Failed to fetch clock account"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ERROR DETECTED] Clock fetch failure. Rotating RPC..." | tee -a "$LOGFILE"
    rotate_rpc
  fi

  if tail -n 50 "$LOGFILE" | grep -q "instruction requires an uninitialized account"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [FATAL ERROR] Detected 'account already initialized' error. Restarting..." | tee -a "$LOGFILE"
    restart_script
  fi

  if tail -n 50 "$LOGFILE" | grep -q "429 Too Many Requests"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [WARNING] RPC is rate-limited. Rotating RPC endpoint..." | tee -a "$LOGFILE"
    rotate_rpc
  fi

  CRASH_COUNT=$((CRASH_COUNT + 1))
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Crash count: $CRASH_COUNT" | tee -a "$LOGFILE"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Log file size: $(du -h $LOGFILE | cut -f1)" | tee -a "$LOGFILE"

  if [ "$CRASH_COUNT" -ge 10 ]; then
    restart_script
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Restarting miner in $RETRY_DELAY seconds..." | tee -a "$LOGFILE"
  sleep "$RETRY_DELAY"
done
