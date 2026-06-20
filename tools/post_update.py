#!/usr/bin/env python3
"""git commit 後に X と Bluesky へ自動投稿するスクリプト。"""

import os
import sys
import subprocess
from pathlib import Path
from dotenv import load_dotenv

SCRIPT_DIR  = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
SCREENSHOT  = SCRIPT_DIR / "screenshot.png"

load_dotenv(PROJECT_DIR / ".env")


def get_last_commit_message():
    result = subprocess.run(
        ["git", "log", "-1", "--pretty=%s"],
        capture_output=True, text=True, encoding="utf-8",
        cwd=PROJECT_DIR
    )
    return result.stdout.strip()


def ask_screenshot_ready() -> bool:
    """F12スクショ確認ダイアログ。Trueならスクショ存在確認済み。"""
    msg = ("ゲーム内で F12 を押してスクショを撮りましたか？\n"
           "（撮影すると tools/screenshot.png に保存されます）")
    try:
        import tkinter as tk
        from tkinter import messagebox
        root = tk.Tk()
        root.withdraw()
        took_shot = messagebox.askyesno("スクショ確認", msg)
        root.destroy()
    except Exception:
        try:
            took_shot = input("F12でスクショを撮りましたか？ [y/N]: ").strip().lower() == "y"
        except EOFError:
            print("非インタラクティブ環境。手動で tools/post_update.py を実行してください。")
            return False

    if not took_shot:
        print("スクショを撮ってから再実行してください。")
        sys.exit(0)

    if not SCREENSHOT.exists():
        print("スクショが見つかりません。F12 で撮影後に再実行してください。")
        sys.exit(1)

    commit_time = subprocess.run(
        ["git", "log", "-1", "--pretty=%ct"],
        capture_output=True, text=True, cwd=PROJECT_DIR
    ).stdout.strip()
    if commit_time and SCREENSHOT.stat().st_mtime <= int(commit_time) + 30:
        print("スクショが古いです。F12 で撮り直してから再実行してください。")
        sys.exit(1)

    return True


def preview_and_confirm(text, has_screenshot):
    print("\n" + "━" * 40)
    print(text)
    print("━" * 40)
    if has_screenshot:
        print(f"\nスクショ: {SCREENSHOT}")
        os.startfile(SCREENSHOT)
    else:
        print("\n（スクショなし）")
    print()

    preview = text[:100] + ("…" if len(text) > 100 else "")
    try:
        import tkinter as tk
        from tkinter import messagebox
        root = tk.Tk()
        root.withdraw()
        result = messagebox.askyesno("SNS投稿確認", f"{preview}\n\nこの内容で投稿しますか？")
        root.destroy()
        return result
    except Exception:
        try:
            answer = input("この内容で投稿しますか？ [y/N]: ").strip().lower()
        except EOFError:
            print("非インタラクティブ環境を検出。手動で tools/post_update.py を実行してください。")
            return False
        return answer == "y"


def post_to_x(text, has_screenshot):
    import tweepy
    media_ids = None
    if has_screenshot:
        auth = tweepy.OAuth1UserHandler(
            os.getenv("X_API_KEY"), os.getenv("X_API_SECRET"),
            os.getenv("X_ACCESS_TOKEN"), os.getenv("X_ACCESS_TOKEN_SECRET"),
        )
        api_v1 = tweepy.API(auth)
        media = api_v1.media_upload(str(SCREENSHOT))
        media_ids = [media.media_id]

    client = tweepy.Client(
        consumer_key=os.getenv("X_API_KEY"),
        consumer_secret=os.getenv("X_API_SECRET"),
        access_token=os.getenv("X_ACCESS_TOKEN"),
        access_token_secret=os.getenv("X_ACCESS_TOKEN_SECRET"),
    )
    response = client.create_tweet(text=text, media_ids=media_ids)
    print(f"X 投稿完了: https://x.com/tamagoyaki42dev/status/{response.data['id']}")


def post_to_bluesky(text, has_screenshot):
    from atproto import Client, models
    client = Client()
    client.login(os.getenv("BSKY_HANDLE"), os.getenv("BSKY_PASSWORD"))

    if has_screenshot:
        with open(SCREENSHOT, "rb") as f:
            img_data = f.read()
        upload = client.upload_blob(img_data)
        embed = models.AppBskyEmbedImages.Main(
            images=[models.AppBskyEmbedImages.Image(
                alt="スクリーンショット",
                image=upload.blob,
            )]
        )
        client.send_post(text=text, embed=embed)
    else:
        client.send_post(text=text)
    print("Bluesky 投稿完了")


def main():
    commit_msg = get_last_commit_message()
    if not commit_msg:
        print("コミットメッセージが取得できませんでした")
        sys.exit(1)

    if "[skip-sns]" in commit_msg:
        print("[skip-sns] タグを検出。SNS投稿をスキップします。")
        sys.exit(0)

    repo_url  = "https://github.com/tamagoyaki42dev/tamagoyaki-game"
    hashtags  = "#indiedev #gamedev #たまごやきゲームス"
    text      = f"【開発更新】{commit_msg}\n\n{repo_url}\n\n{hashtags}"

    def x_len(s):
        url_placeholder = repo_url
        s_no_url = s.replace(url_placeholder, "x" * 23)
        return sum(2 if ord(c) > 0x2E7F else 1 for c in s_no_url)

    post_x = x_len(text) <= 280
    if not post_x:
        print(f"X 文字数オーバー（{x_len(text)}/280）。X への投稿をスキップします。")

    has_screenshot = ask_screenshot_ready()

    if not preview_and_confirm(text, has_screenshot):
        print("投稿をキャンセルしました。")
        sys.exit(0)

    errors = []

    if post_x:
        try:
            post_to_x(text, has_screenshot)
        except Exception as e:
            errors.append(f"X エラー: {e}")

    try:
        post_to_bluesky(text, has_screenshot)
    except Exception as e:
        errors.append(f"Bluesky エラー: {e}")

    if has_screenshot:
        SCREENSHOT.unlink(missing_ok=True)

    if errors:
        for err in errors:
            print(err)
        sys.exit(1)


if __name__ == "__main__":
    main()
