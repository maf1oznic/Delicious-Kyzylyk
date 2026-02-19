import os
import time
import subprocess
import json
import uuid
from datetime import datetime

# === НАСТРОЙКИ ===
XRAY_CONTAINER = os.getenv("XRAY_CONTAINER", "xray")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "1"))
DISCONNECT_TIMEOUT = int(os.getenv("DISCONNECT_TIMEOUT", "60"))
LOG_FILE = "/logs/user-connections.log"

users = {}

def log_event(event, user, session_id, duration=None):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    if duration is not None:
        line = (
            f"{ts} {event} session={session_id} "
            f"user={user} duration={int(duration)}\n"
        )
    else:
        line = f"{ts} {event} session={session_id} user={user}\n"

    with open(LOG_FILE, "a") as f:
        f.write(line)

    print(line.strip(), flush=True)

def get_stats():
    try:
        result = subprocess.check_output(
            [
                "docker", "exec", XRAY_CONTAINER,
                "xray", "api", "statsquery",
                "--server=127.0.0.1:61000"
            ],
            timeout=5
        )
        return json.loads(result)
    except Exception as e:
        print("ERROR getting stats:", e, flush=True)
        return None

def parse_users(stats):
    res = {}
    for item in stats.get("stat", []):
        name = item.get("name", "")
        value = int(item.get("value", 0))

        if name.startswith("user>>>") and "traffic" in name:
            user = name.split(">>>")[1]
            res[user] = res.get(user, 0) + value

    return res

def main():
    # print("Xray online logger with session_id + duration started", flush=True)

    while True:
        now = time.time()
        data = get_stats()
        if not data:
            time.sleep(POLL_INTERVAL)
            continue

        traffic = parse_users(data)

        # CONNECT / activity
        for user, total in traffic.items():
            state = users.get(user)

            if not state:
                users[user] = {
                    "last_total": total,
                    "last_activity": now,
                    "online": False,
                    "session_id": None,
                    "connect_time": None
                }
                continue

            delta = total - state["last_total"]

            if delta > 0:
                state["last_activity"] = now

                if not state["online"]:
                    state["online"] = True
                    state["session_id"] = uuid.uuid4().hex
                    state["connect_time"] = now
                    log_event("CONNECT", user, state["session_id"])

            state["last_total"] = total

        # DISCONNECT
        for user, state in users.items():
            if state["online"] and now - state["last_activity"] > DISCONNECT_TIMEOUT:
                duration = now - state["connect_time"]
                log_event(
                    "DISCONNECT",
                    user,
                    state["session_id"],
                    duration=duration
                )

                state["online"] = False
                state["session_id"] = None
                state["connect_time"] = None

        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()