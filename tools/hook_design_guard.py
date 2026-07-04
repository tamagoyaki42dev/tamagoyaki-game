"""PostToolUse hook: 戦闘バランス土台ファイル編集時に、
design_decisions.md照合＋『勝手な挙動導入』（新規ランダム性/生成/調整値）の検出をリマインドする。"""
import json
import re
import subprocess
import sys

TARGET_FILES = [
    "scripts/battle/battle_manager.gd",
    "scripts/battle/enemy_generator.gd",
    "scripts/data/enemy_data.gd",
    "scripts/data/character_data.gd",
    "scripts/game_state.gd",
    "tests/test_battle_sim.gd",
]

# 新規追加行に現れたら「ユーザーが認識すべき挙動導入」を疑うパターン
BEHAVIOR_PATTERNS = [
    (r"\brandf|\brandi|\.shuffle\(|\.pick_random\(", "ランダム性（乱数・シャッフル）"),
    (r"func\s+from_|func\s+_generate|func\s+_spawn|func\s+make_", "生成/ファクトリロジック"),
    (r"@export", "@export 調整値"),
]


def _added_lines(file_path: str) -> str:
    """git diff HEAD の当該ファイルから、未コミットの追加行（+行）だけを返す。"""
    try:
        r = subprocess.run(
            ["git", "diff", "HEAD", "--", file_path],
            capture_output=True, encoding="utf-8", errors="replace", timeout=10,
        )
        added = []
        for line in r.stdout.splitlines():
            if line.startswith("+") and not line.startswith("+++"):
                added.append(line[1:])
        return "\n".join(added)
    except Exception:
        return ""


def main() -> int:
    try:
        data = json.load(sys.stdin)
        tool_input = data.get("tool_input", {}) or {}
        tool_response = data.get("tool_response", {}) or {}
        file_path = tool_response.get("filePath") or tool_input.get("file_path") or ""
        if not file_path:
            return 0
        norm = file_path.replace("\\", "/")
        target = next((t for t in TARGET_FILES if norm.endswith(t)), None)
        if target is None:
            return 0

        parts = [
            "この変更は戦闘バランスの土台ファイル（%s）に触れています。"
            "docs/design_decisions.md の『触ると死ぬ配線』と矛盾していないか照合してください。" % target
        ]

        # 勝手な挙動導入の検出（未コミットの追加行をパターンマッチ）
        added = _added_lines(norm)
        hits = []
        for pat, label in BEHAVIOR_PATTERNS:
            if re.search(pat, added):
                hits.append(label)
        if hits:
            parts.append(
                "⚠️【勝手な実装の検出】この編集で次の『ユーザーが認識すべき挙動要素』を"
                "新規追加した可能性があります：%s。"
                "ユーザー未承認の新規実装でないか確認し、新機能ならユーザーに一言告げて承認を得てください。"
                % "／".join(hits)
            )

        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": "\n".join(parts),
            }
        }))
        return 0
    except Exception:
        return 0


if __name__ == "__main__":
    sys.exit(main())
