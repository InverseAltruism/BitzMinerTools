#!/bin/bash

EXPORT_FILE="/var/lib/node_exporter/textfile_collector/bitz_miner.prom"

# Token API balance from RPC
API_BALANCE=$(curl -s -X POST https://mainnetbeta-rpc.eclipse.xyz \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "getTokenAccountsByOwner",
    "params": [
      "GHNaCrPRS5gNsb51ktHiaLKQJyAENp2J1c3Ee8npSMn1",
      {
        "programId": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
      },
      {
        "encoding": "jsonParsed"
      }
    ]
  }' | jq -r '.result.value[] | select(.account.data.parsed.info.mint == "64mggk2nXg6vHC1qCdsZdEFzd5QGN4id54Vbho4PswCF") | .account.data.parsed.info.tokenAmount.uiAmountString')

# 24H mined logic using timestamp-based filtering
BITZ_MINED_24H=$(awk -v ts=$(date --date="24 hours ago" +%s) '
  /Confirmed/ {
    match($0, /[0-9]+\.[0-9]{8}/, m)
    if (m[0] && $0 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) {
      match($0, /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/)
      t=mktime(gensub(/[-:]/," ","g",substr($0,RSTART,RLENGTH)))
      if (t > ts) print m[0]
    }
  }' ~/bitzminer.log | awk '!seen[$1]++' | paste -sd+ - | bc)

# Total mined from logs (deduplicated)
BITZ_MINED_TOTAL=$(grep "Confirmed" "$HOME/bitzminer.log" | grep -oP '\d+\.\d{8}' | awk '$1 > 0' | awk '!seen[$1]++' | paste -sd+ - | bc 2>/dev/null)

# Crash count from logs
BITZ_CRASH_COUNT=$(grep -c "Miner exited with code" "$HOME/bitzminer.log")

# Determine active RPC endpoint
BITZ_RPC=$(tail -n 500 "$HOME/bitzminer.log" | grep -o "https://.*eclipserpc.*" | tail -n 1)
[[ "$BITZ_RPC" == *"bitz-000"* ]] && RPC_VALUE=2 || RPC_VALUE=1

# Fallback defaults
BITZ_MINED_24H=${BITZ_MINED_24H:-0}
BITZ_MINED_TOTAL=${BITZ_MINED_TOTAL:-0}
BITZ_CRASH_COUNT=${BITZ_CRASH_COUNT:-0}
API_BALANCE=${API_BALANCE:-0}
RPC_VALUE=${RPC_VALUE:-0}

# Write to Prometheus textfile
cat <<EOF > "$EXPORT_FILE"
# HELP bitz_mined_24h BITZ mined over the last 24h
# TYPE bitz_mined_24h gauge
bitz_mined_24h $BITZ_MINED_24H

# HELP bitz_mined_total BITZ mined total from logs
# TYPE bitz_mined_total gauge
bitz_mined_total $BITZ_MINED_TOTAL

# HELP bitz_account_balance Current on-chain BITZ balance
# TYPE bitz_account_balance gauge
bitz_account_balance $API_BALANCE

# HELP bitz_crash_count Miner crash count
# TYPE bitz_crash_count counter
bitz_crash_count $BITZ_CRASH_COUNT

# HELP bitz_rpc_active Current active RPC endpoint
# TYPE bitz_rpc_active gauge
bitz_rpc_active $RPC_VALUE
EOF
