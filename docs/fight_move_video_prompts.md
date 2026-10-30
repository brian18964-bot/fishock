# 搏魚招式動畫：影片規格與提示詞

遊戲在魚出招時，於搏魚面板下方的「招式區」播放對應動畫；沒出招時不顯示。
放進 `assets/fight_moves/` 就會自動取代程式畫的暫代圖，**沒放的招式維持暫代圖**。

## 檔案規格（必讀）

| 項目 | 規格 |
|---|---|
| 最終格式 | **Ogg Theora，副檔名 `.ogv`**（Godot 4.7 只內建支援這種；不支援 mp4 / webm / mov） |
| 畫面比例 | **16:9**，建議 **576 × 324**（遊戲內顯示 288 × 162，兩倍給高解析螢幕） |
| 長度 | **1.5 ~ 2.5 秒**，**無縫循環**（首尾畫面接得起來）；播放時會一直重複到招式結束 |
| 聲音 | **不要音軌**（遊戲有自己的音效） |
| 透明度 | **不支援**；請用不透明、與遊戲相近的深色背景（下方風格共用段） |
| 鏡頭 | **固定不動**，不要推拉搖移、不要轉場、不要字幕、不要浮水印 |
| 命名 | `dash.ogv` `side_dash.ogv` `leap.ogv` `rock_dive.ogv` `rage.ogv` `rally.ogv` `weed.ogv` |

AI 影片工具通常輸出 mp4，再用 ffmpeg 轉檔（`-an` 去音軌、`scale` 縮到 576×324）：

```
ffmpeg -i input.mp4 -vf "scale=576:324" -c:v libtheora -q:v 7 -an leap.ogv
```

**側向招式的方向**：`side_dash` 請做成「魚由畫面左邊衝向右邊」，遊戲會依實際方向左右鏡像播放。

## 共用風格段（每一支提示詞前面都貼上）

```
2D stylized animation, side-view cutaway of a dark night lake: the water surface as a thin
wavy light line near the top fifth of the frame, deep blue-black water below, a dark brown
muddy lake floor along the bottom. Moody, low-key lighting, limited palette of deep blue,
teal and muted brown, with one bright accent colour for the action. A single freshwater
fish (carp / bass shape) in clean flat silhouette style with a few soft highlights, a thin
fishing line trailing from the fish up and off the top-left of the frame. Static camera,
no camera movement, no text, no watermark, no people. 16:9, 576x324, seamless loop,
2 seconds, 24 fps.
```

## 各招式提示詞（接在共用風格段後面）

1. **dash（衝刺，直線往外）** `dash.ogv`
   `The fish bolts away in a straight, fast burst from the left-centre toward the right, leaving a trail of speed streaks and bubbles; the fishing line snaps taut behind it and trembles. Loop: the fish re-enters from the left edge.`

2. **side_dash（橫衝，左到右）** `side_dash.ogv`
   `The fish darts sideways across the frame from the left edge to the right edge at mid-depth in a sharp horizontal dash, body bending, water streaking behind it, the line whipping across. Loop: it re-enters from the left edge.`

3. **leap（躍出水面）** `leap.ogv`
   `The fish shoots up out of the water, arcs high above the surface in a shower of droplets and ripples, twisting and shaking its head, then splashes back down with expanding rings. The line flicks wildly.`

4. **rock_dive（鑽石縫）** `rock_dive.ogv`
   `The fish dives steeply toward a cluster of dark jagged rocks on the lake floor on the right, its tail thrashing; the fishing line scrapes against a rock edge and tiny sparks and frayed strands flick off. Loop: fish rises back out of the rocks to start again.`

5. **rage（狂暴）** `rage.ogv`
   `The fish turns red and swells, shaking violently in place with a pulsing red aura and jagged spikes of energy radiating outward, eyes burning, water churning around it, bubbles bursting. Accent colour: angry red-orange.`

6. **rally（反撲）** `rally.ogv`
   `A nearly exhausted fish suddenly surges back with a golden glow: concentric golden rings expand outward from its body, sparkling motes rise upward, and it straightens and thrashes with renewed strength. Accent colour: warm gold.`

7. **weed（鑽水草）** `weed.ogv`
   `The fish plunges into a thick patch of swaying green underwater weeds on the lake floor and weaves through them; the fishing line wraps and tightens around the weed stalks, fraying, little bits of line snapping off. Accent colour: vivid green with a red warning tint on the line.`

## 檢查清單
- [ ] 副檔名 `.ogv`、16:9、無音軌、1.5~2.5 秒、能循環
- [ ] 七支風格一致（同一隻魚、同一個湖底背景）
- [ ] 魚不要太小（約佔畫面高度的 1/5 以上），在 288×162 的小畫面也看得清
