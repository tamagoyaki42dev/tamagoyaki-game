"""PreToolUse hook: git commit時、バランス土台ファイルがステージにあればシム検算をリマインドする（ブロックしない）。"""
import json
import subprocess
import sys

TARGET_FILES = [
    "scripts/battle/battle_manager.gd",
    "scripts/battle/enemy_generator.gd",
    "scripts/data/enemy_data.gd",
    "scripts/data/character_data.gd",
    "tests/test_battle_sim.gd",
]


def main() -> int:
    try:
        data = json.load(sys.stdin)
        tool_input = data.get("tool_input", {}) or {}
        command = tool_input.get("command", "") or ""
        if "git commit" not in command:
            return 0

        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only"],
            capture_output=True, encoding="utf-8", errors="replace", timeout=10,
        )
        staged = set(result.stdout.replace("\\", "/").splitlines())
        hit = [t for t in TARGET_FILES if t in staged]
        if not hit:
            return 0

        message = (
            "バランスの土台ファイル（%s）がステージにあります。"
            "シム検算（balance-verifyスキルのシム実行）をまだ走らせていないなら、コミット前に走らせてください。"
            % ", ".join(hit)
        )
        print(json.dumps({
            "systemMessage": message,
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": message,
            },
        }))
        return 0
    except Exception:
        return 0


if __name__ == "__main__":
    sys.exit(main())
