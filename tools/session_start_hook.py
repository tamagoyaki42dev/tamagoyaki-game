"""SessionStart フック: backlog と最新 devlog を Claude のコンテキストに自動注入する。"""
import glob
import json
import os

parts: list[str] = []

try:
    with open("docs/backlog.md", encoding="utf-8") as f:
        parts.append(f.read())
except OSError:
    pass

devlogs = sorted(glob.glob("devlog/*.md"))  # ファイル名が日付なので辞書順＝時系列
if devlogs:
    latest = devlogs[-1]
    try:
        with open(latest, encoding="utf-8") as f:
            parts.append(f"# 最新devlog（{os.path.basename(latest)}）\n\n" + f.read())
    except OSError:
        pass

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "\n\n---\n\n".join(parts),
    }
}))
