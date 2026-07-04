"""PostToolUse hook: 戦闘バランス土台ファイル編集時にdesign_decisions.mdとの照合をリマインドする。"""
import json
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
        tool_response = data.get("tool_response", {}) or {}
        file_path = tool_response.get("filePath") or tool_input.get("file_path") or ""
        if not file_path:
            return 0
        norm = file_path.replace("\\", "/")
        for target in TARGET_FILES:
            if norm.endswith(target):
                message = (
                    "この変更は戦闘バランスの土台ファイル（%s）に触れています。"
                    "docs/design_decisions.md の『触ると死ぬ配線』と矛盾していないか照合してください"
                    "（回復トリガー・regenの役割・敵の強さの主表現など）。" % target
                )
                print(json.dumps({
                    "hookSpecificOutput": {
                        "hookEventName": "PostToolUse",
                        "additionalContext": message,
                    }
                }))
                return 0
        return 0
    except Exception:
        return 0


if __name__ == "__main__":
    sys.exit(main())
