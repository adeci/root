"""Appliance /system/health sensors as a Prometheus textfile."""

import json
import os
import socket
import sys
import time
from pathlib import Path


def encode_length(length):
    if length < 0x80:
        return bytes([length])
    if length < 0x4000:
        return (length | 0x8000).to_bytes(2, "big")
    if length < 0x200000:
        return (length | 0xC00000).to_bytes(3, "big")
    if length < 0x10000000:
        return (length | 0xE0000000).to_bytes(4, "big")
    return b"\xf0" + length.to_bytes(4, "big")


def decode_length(connection):
    first = connection.recv(1)
    if not first:
        raise EOFError("RouterOS API closed connection")
    byte = first[0]
    if byte & 0x80 == 0:
        return byte
    if byte & 0xC0 == 0x80:
        return int.from_bytes(bytes([byte & ~0xC0]) + connection.recv(1), "big")
    if byte & 0xE0 == 0xC0:
        return int.from_bytes(bytes([byte & ~0xE0]) + connection.recv(2), "big")
    if byte & 0xF0 == 0xE0:
        return int.from_bytes(bytes([byte & ~0xF0]) + connection.recv(3), "big")
    return int.from_bytes(connection.recv(4), "big")


def send_sentence(connection, words):
    for word in words:
        data = word.encode()
        connection.sendall(encode_length(len(data)) + data)
    connection.sendall(b"\x00")


def read_sentence(connection):
    words = []
    while True:
        length = decode_length(connection)
        if length == 0:
            return words
        words.append(connection.recv(length).decode(errors="replace"))


def read_until_done(connection):
    sentences = []
    while True:
        sentence = read_sentence(connection)
        sentences.append(sentence)
        if sentence and sentence[0] in ("!done", "!fatal"):
            return sentences


def sentence_attributes(sentence):
    attributes = {}
    for word in sentence[1:]:
        if word.startswith("="):
            key, _, value = word[1:].partition("=")
            attributes[key] = value
    return attributes


def escape_label(value):
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def labels(**pairs):
    return "{" + ",".join(f'{key}="{escape_label(value)}"' for key, value in pairs.items()) + "}"


def emit_metric(lines, metric, value, **label_pairs):
    lines.append(f"{metric}{labels(**label_pairs)} {value}")


def collect_device(device, password):
    started = time.monotonic()
    rows = []
    with socket.create_connection((device["address"], int(device.get("port", "8728"))), timeout=4) as connection:
        send_sentence(connection, ["/login", "=name=" + device["user"], "=password=" + password])
        login = read_until_done(connection)
        if login[-1][0] != "!done":
            raise RuntimeError("RouterOS API login failed")

        send_sentence(connection, ["/system/health/print"])
        for sentence in read_until_done(connection):
            if sentence and sentence[0] == "!re":
                rows.append(sentence_attributes(sentence))
            elif sentence and sentence[0] in ("!trap", "!fatal"):
                raise RuntimeError(sentence_attributes(sentence).get("message", sentence[0]))
    return rows, time.monotonic() - started


metric_for_unit = {
    "C": "janus_routeros_temperature_celsius",
    "RPM": "janus_routeros_fan_speed_rpm",
    "V": "janus_routeros_voltage_volts",
    "A": "janus_routeros_current_amperes",
    "W": "janus_routeros_power_watts",
}


def main(devices_path, output_path):
    devices = json.loads(Path(devices_path).read_text())
    password = Path(os.environ["CREDENTIALS_DIRECTORY"], "routeros-password").read_text().strip()
    output = Path(output_path)

    lines = [
        "# HELP janus_routeros_health_scrape_success Whether RouterOS /system/health API scrape succeeded.",
        "# TYPE janus_routeros_health_scrape_success gauge",
        "# HELP janus_routeros_health_scrape_duration_seconds RouterOS /system/health API scrape duration.",
        "# TYPE janus_routeros_health_scrape_duration_seconds gauge",
        "# HELP janus_routeros_temperature_celsius RouterOS health temperature sensors.",
        "# TYPE janus_routeros_temperature_celsius gauge",
        "# HELP janus_routeros_fan_speed_rpm RouterOS health fan speed sensors.",
        "# TYPE janus_routeros_fan_speed_rpm gauge",
        "# HELP janus_routeros_voltage_volts RouterOS health voltage sensors.",
        "# TYPE janus_routeros_voltage_volts gauge",
        "# HELP janus_routeros_current_amperes RouterOS health current sensors.",
        "# TYPE janus_routeros_current_amperes gauge",
        "# HELP janus_routeros_power_watts RouterOS health power sensors.",
        "# TYPE janus_routeros_power_watts gauge",
    ]

    for device in devices:
        name = device["name"]
        address = device["address"]
        try:
            rows, duration = collect_device(device, password)
            emit_metric(lines, "janus_routeros_health_scrape_success", 1, name=name, address=address)
            emit_metric(lines, "janus_routeros_health_scrape_duration_seconds", f"{duration:.6f}", name=name, address=address)
            for row in rows:
                metric = metric_for_unit.get(row.get("type", ""))
                if not metric:
                    continue
                try:
                    value = float(row["value"])
                except (KeyError, ValueError):
                    continue
                emit_metric(lines, metric, value, name=name, sensor=row.get("name", "unknown"))
        except Exception:
            emit_metric(lines, "janus_routeros_health_scrape_success", 0, name=name, address=address)

    temporary = output.with_suffix(".prom.tmp")
    temporary.write_text("\n".join(lines) + "\n")
    temporary.chmod(0o644)
    temporary.replace(output)


if __name__ == "__main__":
    main(*sys.argv[1:])
