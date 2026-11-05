# -*- coding: utf-8 -*-
"""小时级体检：只读探测，不修数据，不改配置。

退出码 0 = 全绿，1 = 有异常（由 systemd 的 SuccessExitStatus 接住，不触发重启）。
"""
import json, os, subprocess, sys, urllib.request

SERVICES = ["agent-bridge", "agent-health"]
LOCAL = "http://127.0.0.1:%s" % os.environ.get("LOCAL_SERVICE_PORT", "8123")


def probe(path, timeout=3):
    try:
        with urllib.request.urlopen(LOCAL + path, timeout=timeout) as r:
            return r.status == 200
    except Exception:
        return False


def unit_active(name):
    try:
        out = subprocess.check_output(["systemctl", "is-active", name], text=True, timeout=5)
        return out.strip() == "active"
    except Exception:
        return False


def main():
    report = {
        "services": {n: unit_active(n) for n in SERVICES},
        "api": probe("/api/status"),
        "restart_counts": {},
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    ok = all(report["services"].values()) and report["api"]
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
