#!/usr/bin/env python3
"""git commit 後に X と Bluesky へ自動投稿するスクリプト。"""

import os
import sys
import subprocess
from pathlib import Path
from dotenv import load_dotenv

SCRIPT_DIR  = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent


def _resolve_screenshot_path() -> Path:
    """F12スクショは Godot の user:// 配下に保存される。
    Windows では %APPDATA%/Godot/app_userdata/<config/name>/tools/screenshot.png。
    project名は変更に追従できるよう project.godot から読む。"""
    name = "ローテーションハクスラ"
    project_file = PROJECT_DIR / "project.godot"
    if project_file.exists():
        for line in project_file.read_text(encoding="utf-8").splitlines():
            if line.startswith("config/name="):
                name = line.split("=", 1)[1].strip().strip('"')
                break
    return (Path(os.getenv("APPDATA", ""))
            / "Godot" / "app_userdata" / name / "tools" / "screenshot.png")


SCREENSHOT  = _resolve_screenshot_path()

load_dotenv(PROJECT_DIR / ".env")


def get_last_commit_message():
    result = subprocess.run(
        ["git", "log", "-1", "--pretty=%s"],
        capture_output=True, text=True, encoding="utf-8",
        cwd=PROJECT_DIR
    )
    return result.stdout.strip()


def check_screenshot_silent() -> bool:
    """F12スクショが存在すれば使う。タイムスタンプは問わない。"""
    if "--no-screenshot" in sys.argv:
        return False
    return SCREENSHOT.exists()


def print_post_summary(text, has_screenshot):
    print("\n" + "━" * 40)
    print(text)
    print("━" * 40)
    print(f"\nスクショ: {'あり' if has_screenshot else 'なし'}\n")


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
    hashtags  = "#indiedev #GodotEngine #gdscript #claudecode #ゲーム制作 #個人開発 #たまごやきゲームス"
    text      = f"【開発更新】{commit_msg}\n\n{repo_url}\n\n{hashtags}"

    def x_len(s):
        url_placeholder = repo_url
        s_no_url = s.replace(url_placeholder, "x" * 23)
        return sum(2 if ord(c) > 0x2E7F else 1 for c in s_no_url)

    if x_len(text) > 280:
        suffix = f"\n\n{repo_url}\n\n{hashtags}"
        suffix_len = x_len(suffix)
        prefix = "【開発更新】"
        prefix_len = x_len(prefix)
        budget = 280 - prefix_len - suffix_len - 1  # 1 for "…"
        shortened = ""
        count = 0
        for ch in commit_msg:
            w = 2 if ord(ch) > 0x2E7F else 1
            if count + w > budget:
                break
            shortened += ch
            count += w
        text = f"{prefix}{shortened}…{suffix}"

    has_screenshot = check_screenshot_silent()
    print_post_summary(text, has_screenshot)

    errors = []

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
