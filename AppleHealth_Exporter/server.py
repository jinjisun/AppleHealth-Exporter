"""
Windows 本地健康数据接收服务。
监听 5000 端口，接收 iPhone POST 的 JSON 并追加写入 health_data.csv。
"""

from __future__ import annotations

import csv
import json
import os
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, jsonify, request

app = Flask(__name__)

CSV_PATH = Path(__file__).resolve().parent / "health_data.csv"
CSV_COLUMNS = [
    "synced_at",
    "scope",
    "metric",
    "type",
    "value",
    "unit",
    "start_date",
    "end_date",
    "source",
    "metadata",
    "received_at",
]


def ensure_csv_header() -> None:
    if not CSV_PATH.exists() or CSV_PATH.stat().st_size == 0:
        with CSV_PATH.open("w", newline="", encoding="utf-8-sig") as f:
            writer = csv.DictWriter(f, fieldnames=CSV_COLUMNS)
            writer.writeheader()


def append_records(payload: dict) -> int:
    ensure_csv_header()
    synced_at = str(payload.get("synced_at", ""))
    scope = str(payload.get("scope", ""))
    metric = str(payload.get("metric", ""))
    records = payload.get("records") or []
    received_at = datetime.now(timezone.utc).isoformat()

    rows = []
    for item in records:
        if not isinstance(item, dict):
            continue
        rows.append(
            {
                "synced_at": synced_at,
                "scope": scope,
                "metric": metric,
                "type": item.get("type", ""),
                "value": item.get("value", ""),
                "unit": item.get("unit", ""),
                "start_date": item.get("start_date", ""),
                "end_date": item.get("end_date", ""),
                "source": item.get("source", ""),
                "metadata": item.get("metadata") or "",
                "received_at": received_at,
            }
        )

    if not rows:
        return 0

    with CSV_PATH.open("a", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_COLUMNS)
        writer.writerows(rows)

    return len(rows)


@app.route("/api/health", methods=["POST"])
def receive_health():
    if not request.is_json:
        return jsonify({"ok": False, "error": "Content-Type must be application/json"}), 400

    payload = request.get_json(silent=True)
    if payload is None:
        return jsonify({"ok": False, "error": "Invalid JSON body"}), 400

    try:
        count = append_records(payload)
    except (OSError, csv.Error, TypeError, ValueError) as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500

    return jsonify(
        {
            "ok": True,
            "written": count,
            "scope": payload.get("scope"),
            "csv_path": str(CSV_PATH),
        }
    )


@app.route("/health", methods=["GET"])
def health_check():
    return jsonify(
        {
            "ok": True,
            "service": "AppleHealth Exporter Receiver",
            "csv_exists": CSV_PATH.exists(),
            "csv_path": str(CSV_PATH),
        }
    )


if __name__ == "__main__":
    ensure_csv_header()
    host = os.environ.get("FLASK_HOST", "0.0.0.0")
    port = int(os.environ.get("FLASK_PORT", "5000"))
    print(f"Listening on http://{host}:{port}")
    print(f"POST endpoint: http://<your-lan-ip>:{port}/api/health")
    print(f"CSV output: {CSV_PATH}")
    app.run(host=host, port=port, debug=False)
