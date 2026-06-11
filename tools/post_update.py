#!/usr/bin/env python3
"""git commit 後に X と Bluesky へ自動投稿するスクリプト。"""

import os
import sys
import subprocess
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))


def get_last_commit_message():
    result = subprocess.run(
        ["git", "log", "-1", "--pretty=%s"],
        capture_output=True, text=True, encoding="utf-8",
        cwd=os.path.dirname(__file__)
    )
    return result.stdout.strip()


def post_to_x(text):
    import tweepy
    client = tweepy.Client(
        consumer_key=os.getenv("X_API_KEY"),
        consumer_secret=os.getenv("X_API_SECRET"),
        access_token=os.getenv("X_ACCESS_TOKEN"),
        access_token_secret=os.getenv("X_ACCESS_TOKEN_SECRET"),
    )
    response = client.create_tweet(text=text)
    print(f"X 投稿完了: https://x.com/tamagoyaki42dev/status/{response.data['id']}")


def post_to_bluesky(text):
    from atproto import Client
    client = Client()
    client.login(os.getenv("BSKY_HANDLE"), os.getenv("BSKY_PASSWORD"))
    client.send_post(text=text)
    print("Bluesky 投稿完了")


def main():
    commit_msg = get_last_commit_message()
    if not commit_msg:
        print("コミットメッセージが取得できませんでした")
        sys.exit(1)

    repo_url = "https://github.com/tamagoyaki42dev/tamagoyaki-game"
    text = f"【開発更新】{commit_msg}\n\n{repo_url}\n\n#indiedev #gamedev #たまごやきゲームス"

    # X の文字数制限（280文字）チェック
    if len(text) > 280:
        text = text[:277] + "..."

    print(f"投稿内容:\n{text}\n")

    errors = []

    try:
        post_to_x(text)
    except Exception as e:
        errors.append(f"X エラー: {e}")

    try:
        post_to_bluesky(text)
    except Exception as e:
        errors.append(f"Bluesky エラー: {e}")

    if errors:
        for err in errors:
            print(err)
        sys.exit(1)


if __name__ == "__main__":
    main()
