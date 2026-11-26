# 交接文件：目前狀態、使用者的決定、待辦

（2026-11-25 整理。接手前先讀根目錄的 `CLAUDE.md`：溝通、美術、設計原則、測試的守則。）

## 一、目前狀態
- 所有工作都在 `claude/focused-fermi-96pp3r` 分支，它也是這個 repo 的預設分支；最後一次推送的 CI（Web build）通過並已部署。
- 本機全套測試：5610 項、0 失敗（`tests/run_tests.gd`）。
- 遊戲：Godot 4.7.2，3D 夜釣（俯視鏡頭、夜間、煤燈），手機觸控為主，也支援鍵盤。

## 二、這段期間做了什麼（依時間）
### 1. 海浪、濕沙、涉水（沙灘海岸）
使用者要求：看得出浪峰推進與破碎；退水後沙色、反光、乾燥的時序自然；角色的腳和海水接觸準確。
第二輪：腳步漣漪不要粗白圓圈（改成水面本身起伏、只靠光影看得到）；浪體不要厚重、黑硬邊、尖角；浪峰、破浪泡沫、上沖、回流要連貫。
- 共用的浪況：`scripts/surf.gd`（GLSL 與 GDScript 兩邊算法一致）；海面 shader 在 `scripts/run_view_3d.gd` 的 `WATER_SHADER`。
- 水膜與沙的含水量分開：`scripts/surf_wetness.gd`（R 通道沙的含水量、慢乾；G 通道水膜、快退）。
- 涉水：`scripts/surf_wade.gd`（左右腳落地／抬腳事件、漣漪、水花、滴水、濕腳）。
### 2. 海崖
使用者要求：崖壁有大形狀（岩肩、裂谷、小平台、崖腳凹口、一致傾角岩層）、夜間看得出落差、浪擊有力量感的水花、
草地→碎石→裸岩→濕岩的過渡、可以記住的地標。第二輪修了平台旁的直角黑色缺口，並確立**探索原則**（見 CLAUDE.md）：
**不鋪通往崖邊的小徑**，只保留崖尖海釣平台與礁柱地標。
- 崖壁：`run_view_3d.gd` 的 `_cliff_grid`、`CLIFF_*` 常數；浪擊水花：`scripts/surf_splash.gd`。
### 3. 地圖分支與劇情（6 章 26 關）——詳見 `docs/MAP_BRANCHES.md`
### 4. 新天氣：小雨、濃霧、沙塵暴、海霧（`scripts/game_state.gd`、`scripts/weather_3d.gd`）
### 5. 新海魚：月光鰺（moon_jack），由浪人鰺重新配色（使用者：「依現有去改」）
### 6. 使用者試玩前兩關後的修正（教學順序、指引箭頭、通關視窗、柳的提示、自由夜釣）
### 7. 狼的刀具提示、供品教學，以及一輪自主驗證與審查修正
### 8. 雨打水面、背包快滿提醒、角色解鎖、營地的鱷魚先生
- 雨打在水面：每滴雨一個落點亮點加向外擴散、漸淡的漣漪；小雨稀疏、大雨整片密集並讓水面變粗（燈光反光碎成一片）。
  池塘、湖、海都有，下雪的地圖沒有。`WATER_SHADER` 的 `rain`（`Weather3D.rain` 依天氣漸變）。
- 背包快滿提醒：夜釣中大魚（2×2）放不下時提醒一次、完全放不下再提醒一次（`Player._watch_bag`）；
  出發視窗在背包放不下大魚時顯示警告與「整理背包」按鈕（`DepartChooser._bag_warning`）。
- 角色解鎖：一開始只有黑貓；其他角色依 `Campaign.CHARACTER_JOIN` 加入；鱷魚在加入前完全不顯示。
  加入時通關結算寫「新夥伴加入」，回營地也會跳通知。`dev_all_open = true` 時全部角色都開（開發者測試用）。
- 鱷魚先生（營地湖邊、碼頭左邊）：`scripts/croc_quests.gd`。委託「釣 N 條某魚」，完成給金幣；
  完成 30 次後出現專屬委託（釣到 1-5 深林大湖的鱷雀鱔），完成後鱷魚加入角色、不再出現在湖邊。
  第二輪（使用者要求）：他在岸邊來回散步（`scripts/camp_croc.gd`），出現時頭上冒一句短話（「這裡挺溫暖的……」等），
  之後每隔一陣子說一句；有委託可接或可交時頭上有清單圖示（可交時多一個綠勾）；委託內容和獎勵只在走過去對話時才看得到。
  他穿自己的衣服：白色針織染成磚紅色、戴草帽（`scripts/croc_look.gd`，只套在營地的鱷魚先生身上）。
  第三輪（使用者要求）：頭上圖示改成卷軸（`scripts/quest_scroll.gd`，自己畫的，參考使用者給的圖）；
  可以同時有多個委託、每次回營地多給一個（分批給）；每個委託有自己的情境（例：「今天特別想吃那種肚子大大的、頭小小的魚」
  → 交給鱷魚先生 5 條鯉魚 → 150 金幣），魚要真的交出去、可以分批交（2/5）；對話視窗像 MMO 任務 NPC：
  先列出委託（可交付／新的／進行中），點進去看情境、目標、獎勵，再接受、交出或放棄（`scripts/croc_talk.gd`）。
  接了委託後，營地和夜釣畫面左邊會列出委託清單與進度，夜釣中另外顯示身上帶了幾條（`scripts/quest_tracker.gd`）。
  第四輪（使用者要求，素材來自 GitHub release「Des」）：頭上的 2D 卷軸太亮太突兀 → 改成真的 3D 卷軸模型飄在頭上
  （上下浮動、橫向面對鏡頭輕輕擺動，有可交的委託時發出暖光；比原本圖示小 15%）；他的帽子換成使用者給的紳士帽改成的草帽。
  兩個模型都用我們的工具重製（`tools/make_croc_props.py`）：卷軸來自 `r1.blend`（合併、減面、重新上色成舊羊皮紙＋磚紅繩），
  帽子來自 `Hat.obj`（帽簷加寬、前後微垂、重新染成舊奶油色＋深棕帽帶、加草編紋）。原檔不進版控。
  `parchemin.mb` 是 Maya 二進位檔，這裡沒有 Maya 讀不了，所以用 `r1.blend` 的卷軸。對話視窗和左側清單仍用 2D 卷軸圖示。
### 10. 十二星座硬幣（祭壇的極稀有獎品）
- 使用者要求：12 星座硬幣是祭品會出現的極稀有獎品，能力先不寫；外形不要那麼圓（不規則）、厚度 ×1.5、拿掉類似星星的圖案。
- 用 `tools/make_zodiac_coins.py` 從使用者給的 `Zodiac.fbx`＋貼圖重製成我們的資產：把高面數浮雕烘成高度圖，
  用浮雕偵測找出小星星（排除主圖案和外圈），把顏色和高度都補平，重新調成舊金色，再做法線貼圖；
  硬幣本體是我們自己生成的不規則低面數外形（厚度是原本的 1.5 倍）。輸出：`assets/models/items/zodiac_01..12.glb`、
  `assets/sprites/items/zodiac_NN.png`（背包圖示）、`assets/sprites/icons/zodiac_NN.png`（方形圖示）。01 白羊座 … 12 雙魚座。
- 遊戲裡（`scripts/zodiac.gd`）：成功逃離時，除了祭壇的骨頭，還有 1% 機率多給一枚隨機星座硬幣（放進背包，滿了進倉庫），
  通關結算會顯示；稀有度算「傳說」；商人收購 800 金幣。
- 重做資產需要 Blender 的 Python 模組：`python3 -m venv bpyenv && bpyenv/bin/pip install bpy "numpy<2" opencv-python-headless==4.10.0.84 "scipy<1.15"`
  （`bpyenv/` 不進版控，裡面放了 `.gdignore` 讓 Godot 不掃描）；RAR 用 `bsdtar` 解（apt 的 libarchive-tools）。
### 9. 商城收購的拖曳、藥劑選魚看資訊
- 商城「收購」：倉庫、魚缸、魚桶的卡片也能拖到商人視窗賣（原本只有包包能拖），點一下照舊跳出販賣視窗。
- 用在魚身上的道具（恢復活性的藥劑等）：選魚時點魚會先跳出這條魚的資訊卡（稀有度、大小、價值、活性、時間、詞綴），
  並說明能不能用；按「使用」才真的用，「返回」可以換一條。不能用的魚也能點開看原因。

## 三、已定案（使用者決定的，不用再問）
### 劇情與分支
1. 每張地圖分 4～5 支，每支是一個劇情關卡；共 6 章 26 關。地圖順序：湖畔森林 → 秋林 → 雪地森林 → 沙漠綠洲 → 沙灘海岸 → 海崖。
2. 解鎖：同一張地圖依序（x-1 → x-2…）；**整張地圖全部通過**才開下一張地圖。
3. 越後面的分支地圖越大；新增「特大」（XL）尺寸。
4. 每關三顆星：★ 成功離開；★★ 釣到該分支的獨有魚；★★★ 各關挑戰。
5. 獎勵沿用現有的金幣與道具。舊的 25 關取消，舊星數與進度直接重置（只重置一次）。
6. 開發者（使用者本人）全部地圖、分支都開放測試（`Campaign.dev_all_open = true`，**發佈前改 false**）。
7. 每支分支有 1～2 種獨有魚；海圖新做的海魚用現有的改。
8. 新天氣全部要做（小雨、濃霧、沙塵暴、海霧）。
9. **難拿沒關係**：只有傳說獨有魚的 1-4、1-5、3-4、6-3、6-4，★★ 很難拿，維持。
10. **狼多沒關係**：3-3（約 11 隻）、3-4（約 19 隻）維持，改成提示買刀具防身。
### 教學（使用者要求的原則：教到之前，看得到但不能用）
- 反甩（搏魚時往箭頭方向甩，畫面出現「刺！」）在 1-3 教；1-1、1-2 的魚只會衝和跳，不出現箭頭。
- 發光蘑菇、魚氧樹（使用者稱「魚氧草」）、冷凍花、抓小動物、翻石頭：教到之前不能採集。
- 祭壇額度滿後會給魚骨、繼續獻祭可能出現邪惡供品——要寫進教學（1-1 提到魚骨；1-4 額度滿時說明邪惡供品）。
- 狼多的關卡要提示買獵刀、開山刀防身。
### 介面
- 柳的提示不要一直卡在畫面中間：一段時間後淡出，只留指引箭頭。
- 渡石逃離後的通關視窗不能貼底，拿掉不必要的備註。
### 自由夜釣
- 除了隨機生成的風格地圖，要能**自由選擇去哪一支分支釣**（收集各分支的獨有魚）。
- 隨機地圖可以有主題夜晚（使用者舉例「鯉魚風暴」：整張圖都是鯉魚、有機會出現金色鯉魚；其餘自由發想）。

## 四、我先訂、使用者可以再調的數值
| 項目 | 目前值 | 位置 |
|---|---|---|
| 獨有魚混進一般漁獲的機率 | 12% | `FishData.BRANCH_EVERYDAY` |
| 自由夜釣特別夜晚的機率 | 30% | `Campaign.FREE_EVENT_CHANCE` |
| 魚種風暴：該魚佔一般漁獲 | 60% | `FishData.STORM_SHARE` |
| 金色魚機率／價值 | 5%／×5 | `FishData.GOLDEN_CHANCE`、`GOLDEN_VALUE` |
| 暗潮之夜稀有魚、巨物之夜體型 | ×2、×1.25 | `Campaign.FREE_EVENTS` |
| 第六章成就「崖頂夜釣客」金幣 | 300 | `Campaign.ACHIEVEMENTS` |
| 各教學的關卡 | 活餌、蘑菇 1-2；反甩 1-3；狼、供品 1-4；魚氧樹 1-5；冷凍花 3-1 | `Campaign.LESSONS` |
| 柳的提示停留／淡出 | 8 秒／1 秒 | `CampaignHud.BOX_HOLD`、`BOX_FADE` |
| 自由模式的海水魚池 | 維持原樣（稀有、傳說海魚照舊出現；只有劇情關卡才限制他支的獨有魚） | `FishData._branch_pool` |
| 雨打水面的強度（大雨／小雨）、漸變速度 | 1.0／0.26、每秒 0.4 | `Weather3D.RAIN_ON_WATER`、`RAIN_EASE` |
| 雨滴密度、漣漪大小 | 大雨約每平方公尺每秒 3 滴、小雨約 0.8 滴；漣漪半徑 0.24 m | `WATER_SHADER` 的 `RAIN_*`、`rain_rings()` |
| 背包提醒的門檻 | 放不下大魚（2×2）就提醒 | `Inventory.fullness`、`Profile.bag_room_for` |
| 劇情解鎖角色 | 牧羊犬＝第一章、紅鹿（棕鹿）＝第二章、棕熊＝第三章、綿羊＝第四章 | `Campaign.CHARACTER_JOIN` |
| 其他方式解鎖角色 | 吉娃娃＝逃離 30 次、黑面羊＝圖鑑 30%、梅花鹿＝45 顆星、台灣黑熊＝傳說魚 3 條、雪鴞＝入夜後離開 10 次、角鴞＝強光定住大鬼 20 次 | `Campaign.CHARACTER_JOIN` |
| 鱷魚先生：出現 | 通過 1-1 後，每次回營地 60% 在湖邊（有委託完成待交時一定在） | `CrocQuests.FROM_LEVEL`、`CHANCE` |
| 鱷魚先生：委託數量與金幣 | 一般魚 4–8 條 每條 30 金幣（5 條鯉魚＝150，照使用者的例子）；水域特有魚 2–4 條 每條 70；稀有 1 條 300；只選玩家釣過、還沒被委託的魚 | `CrocQuests.NEED`、`GOLD_EACH`、`KIND_WEIGHT` |
| 鱷魚先生：同時的委託數 | 最多 2 個可接、3 個進行中；每次回營地（他在時）多給 1 個 | `CrocQuests.OFFER_MAX`、`ACTIVE_MAX`、`come_by()` |
| 鱷魚先生：交魚 | 從背包、活魚扣、魚缸、倉庫、魚桶找；不交上鎖、金色、腐敗的魚；先交最便宜的 | `CrocQuests.fish_for()`、`give()` |
| 鱷魚先生：情境文字 | 各魚種專屬 28 則、通用 6 則、專屬委託 1 則 | `CrocQuests.STORY`、`ANY_STORY`、`DREAM_STORY` |
| 鱷魚先生：專屬委託 | 完成 30 次後，釣到鱷雀鱔（1-5），500 金幣＋鱷魚加入 | `CrocQuests.JOIN_AFTER`、`DREAM_FISH`、`DREAM_GOLD` |
| 鱷魚先生：散步與說話 | 散步速度＝走路步速×0.7、每處停 5–11 秒；開場白 1.5 秒後、之後每 14–26 秒一句、每句 4.5 秒；台詞都在 `OPENING`、`IDLE_LINES`、`OFFER_LINES`、`DONE_LINES` | `scripts/camp_croc.gd` |
| 鱷魚先生：衣服顏色 | 毛衣磚紅；帽子（使用者的紳士帽改的）奶油色、帽帶深棕 | `CrocLook.SHIRT`；帽子顏色在 `tools/make_croc_props.py` 的 `CREAM`、`BAND` |
| 鱷魚先生：頭上的 3D 卷軸 | 長 0.62 m、離地 2.2 m、上下浮動 0.05 m、橫向面對鏡頭左右擺動 ±0.4 弧度、有可交委託時暖光 0.6 | `CampCroc.SCROLL_LEN`、`SCROLL_UP`、`SCROLL_BOB`、`SCROLL_SWAY`、`SCROLL_TURN`、`SCROLL_GLOW` |
| 星座硬幣 | 成功逃離時 1% 多給一枚（12 種機率相同）；商人收購 800 金幣 | `Zodiac.CHANCE`、`PRICE` |

## 五、待辦與需要使用者決定的事
1. **鱷魚先生**已做（規則都是我先訂的，見第四節）：可同時多個委託、魚要真的交出去、可分批交。
   使用者說過「先暫定」專屬委託是某張地圖的夢幻魚，目前用 1-5 的鱷雀鱔（鱷魚找鱷雀鱔）。
2. **發佈前**把 `Campaign.dev_all_open` 改成 `false`（它也讓所有角色都能選）。
3. 月光鰺目前和浪人鰺同一個模型形狀；更細長的版本已寫好算圖設定（`tools/render_fish.py` 的 moon_jack），要有 Blender（bpy）才能重算。
4. 沙灘海岸的地形設定裡列了「螃蟹」，但遊戲沒有螃蟹這個物種（`shore_critter_count` 為 0，所以不會生成）。**使用者之後會給螃蟹美術。**
5. 背包會被帶回來的魚骨慢慢塞滿——已加提醒（見第二節 8）。
9. **星座硬幣的能力**：使用者說先不寫，目前只是收藏品（可賣 800）。之後要加能力時在 `scripts/zodiac.gd`。
   使用者給的 `parchemin.mb`（Maya 檔）讀不了；如果想用那個卷軸，請匯出成 FBX／OBJ。
8. 之後的多人模式：使用者構想在某張地圖裡突然遇到角色、一起逃出，進而開啟多人玩法並解鎖該角色（尚未做）。
6. 屬性門檻（使用者已接受「卡關」）：海水稀有魚（浪人鰺、蘇眉、翻車魚、雨傘旗魚、鎚頭鯊）和 1-4 巨型鯰魚、1-5 鱷雀鱔算史詩，
   要兩項屬性約 49–57；傳說（劍旗魚、藍鰭鮪）三項約 81–95；新角色只有力量 6、韌性 7、反應 10、耐力 8。
   用基本裝備時，5-3、5-4、6-1 的時間偏緊（很多上鉤的魚拉不起來）。如果使用者之後想調，改 `FishData.GATE_BANDS` 或關卡的額度、時間。
7. 曾經出現一次、之後重跑 10 次都沒再出現的狀況：依序通關驗證時 1-3 有一次沒能達標，原因未查到。

## 六、怎麼驗證（工具都在 repo 裡）
- 測試：見 CLAUDE.md。跟這段工作最相關的測試：`test_campaign_levels_build`（26 關的地圖、水域、鬼、額度）、
  `test_campaign_unlocks_and_achievements`、`test_story_lessons`、`test_tutorials_completable`、`test_branch_fish`、
  `test_free_branches_and_nights`、`test_level_guide_and_results`、`test_weathers`（含雨打水面）、`test_journey_page`、
  `test_bag_full_reminders`、`test_character_unlocks`、`test_croc_quests`、`test_croc_errands_on_run`、`test_zodiac_coins`。
- `tools/verify/verify.gd`（用法寫在檔案開頭）：
  - `tool=bot`：機器人用真實操作（拋竿、揚竿、搏魚、獻祭、逃離）逐關玩，輸出每關用時、額度、漁獲、獨有魚、教學進度、失敗原因。
  - `tool=play`：關掉開發者全開，依序通關 26 關，檢查解鎖順序、星數、首次通關獎勵。
  - `tool=catch_sim`：用遊戲的抽魚程式每關抽 2 萬次，算獨有魚出現率。
  - `tool=shots`（要 xvfb）：每關實機截圖與鳥瞰；`tools/verify/sheet.py` 拼成總覽圖。
  - `tools/verify/weather_odds.py`：每關天氣機率（不用 Godot）。
- 機器人最後一輪結果（基本裝備）：26 關過 23 關；2-4、5-3、5-4 是天黑後被大鬼抓（機器人不會躲大鬼、不用燈），5-3 只差 2 點額度。

## 七、主要檔案與參數
| 內容 | 位置 |
|---|---|
| 章節、26 關（規則、星數、獎勵、提醒 `tip`）、預設規則、地圖尺寸 | `scripts/campaign.gd`：`CHAPTERS`、`LEVELS`、`DEFAULT_RULES`、`MAP_SIZES` |
| 教學內容、操作說明、柳的補充說明、教學關卡 | `scripts/campaign.gd`：`TUTORIALS`、`CONTROLS`、`ASIDES`、`LESSONS`、`taught()` |
| 自由夜釣（分支、特別夜晚） | `scripts/campaign.gd`：`begin_free()`、`FREE_EVENTS`；畫面：`scripts/depart_chooser.gd` |
| 成就 | `scripts/campaign.gd`：`ACHIEVEMENTS` |
| 魚種、獨有魚、魚池、屬性門檻、金色魚 | `scripts/fish_data.gd`：`FISH`、`pool_for()`、`BRANCH_*`、`GATE_*`、`storm_fish`、`icon_of()` |
| 搏魚箭頭（反甩）開關 | `scripts/fish_fight.gd`：`prompts` |
| 天氣種類、機率、供品與邪惡供品 | `scripts/game_state.gd`：`Weather`、`weather_odds()`、`OFFERING_ADD_THRESHOLD`、`RARITY_EVIL_CHANCE`、`MAX_EVIL` |
| 3D 天氣（雨、沙、霧） | `scripts/weather_3d.gd` |
| 關卡畫面上的目標、柳的提示、指引箭頭 | `scripts/campaign_hud.gd` |
| 通關視窗 | `scripts/campaign_results.gd`（`fit()` 縮到放得下） |
| 劇情模式頁（章節分頁、關卡卡片） | `scripts/journey.gd` |
| 採集與互動的限制（教到才能用） | `scripts/player.gd`：`interaction()`、`reachable_*()` |
| 地圖生成（主題、水域、碼頭、動物、蘑菇、魚氧樹） | `scripts/map_generator.gd` |
| 3D 場景（海、崖、湖、天氣、燈光） | `scripts/run_view_3d.gd` |
| 角色解鎖條件 | `scripts/campaign.gd`：`CHARACTER_JOIN`、`character_open()`、`check_characters()`；畫面：`scripts/character_page.gd` |
| 鱷魚先生（委託、出現、專屬委託） | `scripts/croc_quests.gd`；營地散步與台詞：`scripts/camp_croc.gd`；衣服與帽子：`scripts/croc_look.gd`；頭上 3D 卷軸：`scripts/camp_croc.gd` 的 `_make_scroll()`；模型轉換：`tools/make_croc_props.py`；對話視窗：`scripts/croc_talk.gd`；卷軸圖示：`scripts/quest_scroll.gd`；左側委託清單：`scripts/quest_tracker.gd`；頭上泡泡：`scripts/title_screen.gd` 的 `_croc_over()` |
| 十二星座硬幣 | `scripts/zodiac.gd`（`CHANCE`、`PRICE`、`roll()`）；給予：`scripts/game_state.gd` 的 `escape()`；轉換工具：`tools/make_zodiac_coins.py` |
| 商城收購 | `scripts/shop.gd`：`_fill_sell_pane()`、`_sell_drag()`、`SellBoard` |
| 用在魚身上的道具的選魚視窗 | `scripts/fish_pick_panel.gd`：`show_fish()` |
