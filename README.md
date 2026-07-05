<div align="center">

# VocPass

**高職通用校務查詢系統**

[![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)](https://github.com/VocPass/android)
[![Flutter](https://img.shields.io/badge/Flutter-3.32+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-6.0+-green)](https://github.com/VocPass/android/releases/latest/download/vocpass.apk)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue)](https://github.com/VocPass/ios)
[![License](https://img.shields.io/badge/license-GPL--3.0-green)](LICENCE)

> 此為 [HansHans135/shin-her](https://github.com/HansHans135/shin-her) 的原生 App 版本，與 Claude Code 協作開發

</div>

---

## ✨ 功能特色

| 功能 | 說明 |
|------|------|
| 📅 **課表查詢** | 查看每週課表，支援離線快取，無需每次重新載入 |
| 📊 **成績查詢** | 第一、二學期及學年成績，各科目一覽無遺 |
| 🕐 **缺曠統計** | 自動統計曠課、事假、病假、公假，即時掌握距 1/3 門檻狀況 |
| ⭐ **獎懲記錄** | 功過明細、核定日期、銷過狀態完整呈現 |
| 🏠 **桌面小工具** | 課表 Home Screen Widget，桌面直接看到當前課程 |
| 🔔 **推播通知** | 透過 Firebase Cloud Messaging 接收系統與活動通知 |
| 🔐 **驗證碼自動辨識** | 使用 Google ML Kit 文字辨識自動辨識登入驗證碼，免除手動輸入 |
| 💬 **校園論壇** | 匿名發文、標籤分類、檢舉與審核 |
| 🍜 **吃啥？** | 學校周邊餐廳推薦與投稿 |
| 📅 **揪團（When2Meet）** | 建立活動、統計大家的可用時段 |
| 🖼️ **課表桌布產生器** | 依個人課表一鍵產生手機桌布 |
| 👀 **好友課表** | 追蹤並查看好友的課表 |

---

## 📱 支援平台

- **Android** >= 6.0

## 🏫 支援學校

學校擴充支援請至 [Server](https://github.com/VocPass/server) 查看。

## 🛠️ 技術棧

- **Flutter** — 全 UI 框架
- **google_mlkit_text_recognition** — 驗證碼 OCR 辨識
- **flutter_inappwebview** — 學校系統登入與資料擷取
- **firebase_messaging** — 推播通知
- **home_widget** — 桌面小工具
- **shared_preferences** — 本地快取與帳號記憶

## 🚀 安裝

### 從原始碼建置

```bash
git clone https://github.com/VocPass/android.git
cd android
flutter pub get
flutter run
```

以 VS Code 或 Android Studio 開啟 `android` 資料夾亦可直接執行與偵錯。

> 需 Flutter 3.32.1+ 及 Dart 3.8.1+

### 直接安裝 APK

至 [Releases](https://github.com/VocPass/android/releases/latest) 下載最新版 `vocpass.apk` 安裝。

## 🤝 貢獻

歡迎提交 Issue 或 PR！

- **新增學校支援**：前往 [Server](https://github.com/VocPass/server) 貢獻
- **功能建議**：開 Issue 討論
- **Bug 回報**：請附上裝置型號、Android 版本與重現步驟

## 相關專案

| Repo | 說明 |
|------|------|
| [VocPass/server](https://github.com/VocPass/server) | 後端 API 伺服器 |
| [VocPass/ios](https://github.com/VocPass/ios) | iOS / iPadOS / macOS 原生 App |
| [VocPass/bot](https://github.com/VocPass/bot) | Discord 狀態機器人 |

## 📄 授權

本專案採用 [GPL-3.0 License](LICENCE) 授權。
