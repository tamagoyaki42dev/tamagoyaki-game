"""SessionStart フック: backlog・最新 devlog・今日のSNS当番を Claude のコンテキストに自動注入する。"""
import datetime
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

# 今日のSNS当番（週次スケジュール・曜日固定／詳細は docs/sns_workflow.md）
_WEEKDAY_DUTY = {
    2: "水曜: 動画（YouTube＋TikTok）を1本作って両方へ投稿",
    5: "土曜: note記事＋itch devlog（その週の開発ストーリー）",
}
_duty = ["毎日: X投稿（Claude見下し実況）1本 ※在庫から出す・毎日はネタを考えない"]
_today_duty = _WEEKDAY_DUTY.get(datetime.date.today().weekday())
if _today_duty:
    _duty.append(_today_duty)
parts.append(
    "# 今日のSNS当番（週次スケジュール・詳細は docs/sns_workflow.md）\n\n"
    + "\n".join(f"- {d}" for d in _duty)
)

# 水・土は「投稿日リマインド」を最優先でコンテキスト先頭に立てる（ユーザー要望・2026-07-16）。
# フックが動くのはその日にセッションを開いたときだが、動画/note は Claude と一緒に作る作業なので実質必ず引っかかる。
if _today_duty:
    parts.insert(0,
        "# ⚠️ 投稿日リマインド（この応答の冒頭で必ずユーザーに知らせること）\n\n"
        f"今日は投稿日です → **{_today_duty}**。\n"
        "作業に入る前に、まず第一声でこの投稿予定をユーザーにリマインドすること"
        "（すでに投稿済みなら「対応済みならOK」と添える）。"
    )

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "\n\n---\n\n".join(parts),
    }
}))
