#!/usr/bin/env python3
"""コミット後に devlog/{date}.md へ自動追記するスクリプト。"""

import os
import subprocess
from datetime import datetime


def get_last_commit_message():
    result = subprocess.run(
        ["git", "log", "-1", "--pretty=%s"],
        capture_output=True, text=True, encoding="utf-8",
        cwd=os.path.dirname(__file__)
    )
    return result.stdout.strip()


def get_repo_root():
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, encoding="utf-8",
        cwd=os.path.dirname(__file__)
    )
    return result.stdout.strip()


def main():
    commit_msg = get_last_commit_message()
    if not commit_msg:
        return

    now = datetime.now()
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%H:%M")

    repo_root = get_repo_root()
    devlog_dir = os.path.join(repo_root, "devlog")
    os.makedirs(devlog_dir, exist_ok=True)
    devlog_path = os.path.join(devlog_dir, f"{date_str}.md")

    entry = f"\n## {time_str} {commit_msg}\n"

    if not os.path.exists(devlog_path):
        with open(devlog_path, "w", encoding="utf-8") as f:
            f.write(f"# Devlog {date_str}\n{entry}")
    else:
        with open(devlog_path, "r", encoding="utf-8") as f:
            content = f.read()

        NEXT_SESSION_MARKER = "\n## 次のセッションでやること"
        if NEXT_SESSION_MARKER in content:
            idx = content.index(NEXT_SESSION_MARKER)
            content = content[:idx] + entry + content[idx:]
        else:
            content += entry

        with open(devlog_path, "w", encoding="utf-8") as f:
            f.write(content)

    # 次のコミットに含まれるよう staging に追加
    subprocess.run(["git", "add", devlog_path], cwd=repo_root)
    print(f"Devlog 更新: devlog/{date_str}.md")


if __name__ == "__main__":
    main()
