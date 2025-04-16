# BitzMinerTools

Comprehensive monitoring and management toolkit for your Bitz Miner, built with:
- **Node Exporter** for metric collection
- **Prometheus** for time series data
- **Grafana** for rich visualization

> **NOTE:** A full auto-installer is in progress. For now, setup is manual and assumes basic familiarity with Linux CLI.

---

## 📦 What’s Included

- `bitz_runner.sh` — your mining script with auto-RPC switch, reward claiming, and crash tracking.
- `bitz_exporter.sh` — custom Prometheus exporter that:
  - Extracts on-chain BITZ token balance
  - Aggregates mined tokens in last 24h
  - Tracks miner crash counts
  - Records currently active RPC endpoint
- **Grafana Dashboard JSON** — prebuilt panel layout for importing and visualizing metrics.

---

## ⚙️ Requirements

You need to install the following manually **before using the scripts**:

### 🧱 System dependencies
- `curl`, `jq`, `awk`, `bc`, `grep`, `mktime`
- Your Linux distribution likely has these. Install via apt/yum/pacman if missing.

### 💻 Prometheus
- Download & install from: https://prometheus.io/download
- Config file: `/etc/prometheus/prometheus.yaml`
- Must scrape:
```yaml
  - job_name: 'node-exporter-job'
    scrape_interval: 5s
    static_configs:
      - targets: ['127.0.0.1:9100']
```

### 📈 Grafana
- Install from: https://grafana.com/grafana/download
- Import the included JSON via `+ > Import > Upload JSON file`

### 📡 Node Exporter
- Download: https://github.com/prometheus/node_exporter
- Install as a systemd service
- Add the `--collector.textfile.directory=/var/lib/node_exporter/textfile_collector` option
- Make sure this folder is writable by the Prometheus exporter (owned by the node-exporter user)

### 🌐 Solana CLI
- Required for the `solana config set --url ...` part in `bitz_runnerV5.sh`
- https://docs.solana.com/cli/install-solana-cli-tools

---

## 📝 Setup Steps (Manual)

1. **Clone this repo locally**
2. Make the scripts executable:
   ```bash
   chmod +x ~/bitz_runnerV5.sh ~/bitz_exporter.sh
   ```
3. **Set up crontab and screen**:
   ```cron
   @reboot screen -dmS bitzminer /home/YOURUSER/bitz_runnerV5.sh
   * * * * * /home/YOURUSER/bitz_exporter.sh
   ```

4. **Run exporter manually to test**:
   ```bash
   bash ~/bitz_exporter.sh
   curl -s http://localhost:9100/metrics | grep bitz_
   ```
5. **Start Grafana and import the dashboard**

---

## 📊 Metrics Provided
| Metric | Description |
|--------|-------------|
| `bitz_mined_24h` | BITZ mined in the last 24h (from log timestamps) |
| `bitz_mined_total` | Total mined BITZ (deduplicated from log) |
| `bitz_account_balance` | Live on-chain token balance fetched from RPC |
| `bitz_crash_count` | Count of crash loops detected |
| `bitz_rpc_active` | `1 = main`, `2 = backup` RPC endpoint |

---

## ✅ To-Do / Planned
- [ ] Full installer script (auto-deploys everything)
- [ ] Docker container support
- [ ] Multi-wallet miner support

---

## 🧠 Author & Contributions

Maintained by **@InverseAltruism**.
Feel free to fork, improve, or open issues.

---

## Socials

Feel free to follow my twitter - https://x.com/0xInverse
Join my TG - https://t.me/OxInverse

---

## 📜 License
MIT