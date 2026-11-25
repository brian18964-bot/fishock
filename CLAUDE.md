# Fishock 開發守則（給接手的 Claude Code）

先讀 `docs/HANDOFF.md`（目前狀態、使用者的決定、待辦），劇情／分支設計看 `docs/MAP_BRANCHES.md`。
`docs/CAMPAIGN.md` 是舊的五章 25 關設計，已被分支關卡取代，只當背景參考。

## 跟使用者溝通
- 一律用**繁體中文**回報。說明改了什麼、怎麼看效果、主要參數在哪、實際驗證結果。
- 會影響玩法的**數值**（機率、時間、額度、金幣、數量）由使用者決定：可以提出建議或先訂一個值，但要明講「這是我先訂的、可以改」，不要默默改動使用者訂過的數值。
- 使用者已經決定、不必再問的事，見 `docs/HANDOFF.md`「已定案」一節。

## 美術資產
- 使用者上傳的原始美術檔**絕不進版控**。只提交經過我們自己的工具轉換後的資產與轉換工具本身
  （使用者原話：「使用前都要透過我們自己的修正，變成我們的資產」）。`tools/` 裡的 make_*/build_* 就是這類轉換工具。

## 設計原則（使用者明確要求）
- **探索**：玩家要自己探索水域。地貌自然、多樣，讓玩家自己觀察、接近、發現水域和站位；不要明顯通往崖邊的線性小徑、
  強烈燈光導引或強制導覽。地標用來辨認方位、記憶位置。可行走的地面、碰撞和高低落差要清楚一致，不能有隱形邊界或意外踩空。
- **教了才能用**：劇情裡還沒教到的東西，玩家只能看到、不能使用（`Campaign.LESSONS` / `Campaign.taught()`）。
- **允許卡關**：「總有一些關卡要卡著」——★★ 難拿、某些魚要靠裝備屬性才拉得起來，都是可以接受的。

## 程式慣例
- Godot 4.7.2（GDScript）。網頁版由 GitHub Actions「Web build」測試、匯出並部署。
- 程式註解用英文散文寫明**為什麼**，使用者提出的改動寫成 `User request:` / `User report:` 開頭，照現有檔案的風格。
- 每個改動都要有對應測試：`tests/scenarios.gd`（加進 `TESTS` 清單，用 `check()`），跑的是真正的遊戲場景。
- commit 訊息用英文、照現有歷史的散文風格（標題一句，內文說明使用者要求與改了什麼）。不要在 commit、程式或文件裡寫模型名稱。

## 測試與驗證
- 單項測試：`godot --headless --fixed-fps 60 -s tests/run_tests.gd -- only=test_xxx,test_yyy`
- 全套（約 25–30 分鐘）：`godot --headless --fixed-fps 60 -s tests/run_tests.gd`；推送前跑全套，推送後確認 CI 綠燈。
- 新環境先照 CI 的步驟：下載 Godot 4.7.2、`godot --headless --import` 兩次，再跑測試。
- 一次只開一個 Godot（容器資源有限）。
- 測試自己的回合不會擲自由夜釣的特別夜晚（`Campaign.free_events = false`，在 `_fresh_game()` 設定）。
- 截圖（真實繪圖）：`xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 60 -s ...`，
  可參考 `tools/loading_shots_work.gd` 的 `begin()`、`aim()`、`shot()`、`hud()`。
- 關卡驗證工具在 `tools/verify/`（機器人實際玩關、依序通關、抽魚模擬、逐關截圖、天氣機率），用法寫在 `tools/verify/verify.gd` 開頭。

## 發佈前必做
- `scripts/campaign.gd` 的 `Campaign.dev_all_open` 改成 `false`（目前為了讓使用者測試，所有章節、關卡、自由模式分支全開）。
