#!/usr/bin/env python3
"""
VocPass — 課程動態常駐通知 FCM 推送程式
==========================================

當 App 被使用者關閉（或在背景）時，前端的 DynamicIslandService 不會再每秒更新
那條常駐通知。這支程式由伺服器端（或排程 / cron）呼叫，透過 FCM **data message**
把當天課表推給裝置，Android 端的 VocPassFirebaseMessagingService 收到後會解析出
「這節課 / 下節課 / 倒數」並重建常駐通知。

Kotlin 端（VocPassFirebaseMessagingService.parseCurriculumToClassStatus）預期的
payload 是 data message，key 為 "curriculum"，value 為 **扁平 JSON 陣列字串**，
每個元素欄位如下（時間為 24 小時制 "HH:MM"）：

    {
      "period":    "第六節",
      "subject":   "數位電子實習",
      "room":      "電子二甲",
      "startTime": "14:10",
      "endTime":   "15:00"
    }

用法
----
1. 安裝相依套件：
       pip install firebase-admin
2. 準備 Firebase 服務帳戶金鑰（Firebase 主控台 → 專案設定 → 服務帳戶 → 產生新的私密金鑰），
   存成 service-account.json，或用環境變數 GOOGLE_APPLICATION_CREDENTIALS 指向它。
3. 執行：
       python send_class_status_fcm.py \
           --token <裝置 FCM token> \
           --curriculum today_curriculum.json
   或用內建示範課表快速驗證：
       python send_class_status_fcm.py --token <FCM token> --demo
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import warnings
from typing import Any, Iterable

# Kotlin 端會讀取的欄位；多餘欄位會被忽略，缺少的以空字串補上。
REQUIRED_FIELDS = ("period", "subject", "room", "startTime", "endTime")


def _import_firebase():
    """延遲載入 firebase-admin，讓 --dry-run 不需要安裝相依套件。"""
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging
    except ImportError:  # pragma: no cover - 相依套件缺失時給清楚提示
        sys.stderr.write(
            "找不到 firebase-admin，請先安裝：\n    pip install firebase-admin\n"
        )
        sys.exit(1)
    return firebase_admin, credentials, messaging


def init_firebase(service_account_path: str | None) -> None:
    """初始化 Firebase Admin SDK（僅初始化一次）。"""
    firebase_admin, credentials, _ = _import_firebase()
    if firebase_admin._apps:  # 已初始化過就沿用
        return

    if not service_account_path:
        sys.stderr.write(
            "缺少 Firebase 服務帳戶金鑰。請擇一：\n"
            "  1. 加上 --service-account <path>\n"
            "  2. 設定環境變數 GOOGLE_APPLICATION_CREDENTIALS 指向金鑰 JSON\n"
            "金鑰取得：Firebase 主控台 → 專案設定 → 服務帳戶 → 產生新的私密金鑰。\n"
            "（只想檢查 payload、不實際送出，可加 --dry-run。）\n"
        )
        sys.exit(1)

    if not os.path.isfile(service_account_path):
        sys.stderr.write(f"找不到服務帳戶金鑰檔：{service_account_path}\n")
        sys.exit(1)

    # 從金鑰檔取出 project_id 明確傳入，避免某些環境推導不到而報
    # 「Project ID is required to access Cloud Messaging service」。
    try:
        with open(service_account_path, "r", encoding="utf-8") as fh:
            project_id = json.load(fh).get("project_id")
    except (OSError, ValueError):
        project_id = None

    cred = credentials.Certificate(service_account_path)
    options = {"projectId": project_id} if project_id else None
    firebase_admin.initialize_app(cred, options)


def normalize_curriculum(raw: Iterable[dict[str, Any]]) -> list[dict[str, str]]:
    """把課表整理成 Kotlin 端預期的扁平陣列，欄位齊全且皆為字串。"""
    normalized: list[dict[str, str]] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        entry = {field: str(item.get(field, "")).strip() for field in REQUIRED_FIELDS}
        # 沒有科目或沒有起訖時間的節次對通知沒意義，直接略過。
        if not entry["subject"] or not entry["startTime"] or not entry["endTime"]:
            continue
        normalized.append(entry)

    # 依開始時間排序，讓 Kotlin 端挑「這節 / 下節」時更穩定。
    normalized.sort(key=lambda e: _minutes(e["startTime"]))
    return normalized


def _minutes(hhmm: str) -> int:
    try:
        hour, minute = hhmm.split(":")[:2]
        return int(hour) * 60 + int(minute)
    except (ValueError, IndexError):
        return 0


def load_curriculum(path: str) -> list[dict[str, str]]:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, list):
        raise ValueError("課表 JSON 檔的最外層必須是陣列 (list)。")
    return normalize_curriculum(data)


def demo_curriculum() -> list[dict[str, str]]:
    """對應參考截圖的示範課表，方便快速驗證通知樣式。"""
    return normalize_curriculum(
        [
            {"period": "第五節", "subject": "數位電子實習", "room": "電子二甲",
             "startTime": "1:10", "endTime": "8:00"},
            {"period": "第六節", "subject": "數位電子實習", "room": "電子二甲",
             "startTime": "08:00", "endTime": "09:00"},
            {"period": "第七節", "subject": "數位電子實習", "room": "電子二甲",
             "startTime": "09:00", "endTime": "21:05"},
        ]
    )


def send(token: str, curriculum: list[dict[str, str]], dry_run: bool) -> None:
    if not curriculum:
        print("課表為空，沒有可推送的內容。", file=sys.stderr)
        return

    if dry_run:
        print("[dry-run] 將送出的 data payload：")
        print(json.dumps(
            {"token": token, "curriculum": curriculum},
            ensure_ascii=False,
            indent=2,
        ))
        return

    _, _, messaging = _import_firebase()
    # 刻意 **只帶 data、不帶 notification**：帶 notification 欄位時，App 在背景/被關閉
    # 的情況下 onMessageReceived 不一定會被叫到（系統會自行顯示），我們需要自己接手重建
    # 常駐通知，所以走純 data message，並用 HIGH priority 盡量即時喚醒。
    #
    # firebase-admin 7.x 對 Message.token 發 DeprecationWarning（建議改用 fid）。
    # 但我們拿到的是裝置的 FCM registration token，不是 Firebase Installation ID，
    # 這裡就是該用 token，故抑制這條誤導性警告。
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore", category=DeprecationWarning, module="firebase_admin.*"
        )
        message = messaging.Message(
            token=token,
            data={"curriculum": json.dumps(curriculum, ensure_ascii=False)},
            android=messaging.AndroidConfig(priority="high"),
        )
        response = messaging.send(message)
    print(f"已送出，message id = {response}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="推送 VocPass 課程動態常駐通知（FCM data message）。",
    )
    parser.add_argument(
        "--token",
        required=True,
        help="目標裝置的 FCM registration token。",
    )
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument(
        "--curriculum",
        help="課表 JSON 檔路徑（最外層為陣列，欄位見檔頭說明）。",
    )
    src.add_argument(
        "--demo",
        action="store_true",
        help="使用內建示範課表（對應參考截圖）。",
    )
    parser.add_argument(
        "--service-account",
        default=os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"),
        help="Firebase 服務帳戶金鑰 JSON 路徑；預設讀 GOOGLE_APPLICATION_CREDENTIALS。",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="只印出 payload，不實際送出（也不需要金鑰）。",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    curriculum = demo_curriculum() if args.demo else load_curriculum(args.curriculum)

    if not args.dry_run:
        init_firebase(args.service_account)

    send(args.token, curriculum, args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
