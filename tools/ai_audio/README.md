# AI 生成音樂、環境音、音效與角色語音

用三個開源模型，在你自己的電腦上產生遊戲用的聲音，取代目前程式合成的音效：

| 要做的 | 模型 | 授權 | 腳本 |
|---|---|---|---|
| 背景音樂（營地、夜釣、白天） | [ACE-Step 1.5](https://github.com/ace-step/ACE-Step-1.5) | MIT | `gen_music.py` |
| 環境音（營火、湖、風、雨…）與音效（水花、拋竿、腳步…） | [MOSS-SoundEffect v2](https://github.com/OpenMOSS/MOSS-TTS/tree/main/moss_soundeffect_v2) | Apache-2.0 | `gen_sfx.py` |
| 角色語音（青蛙商人、柳樹精靈） | [Qwen3-TTS](https://github.com/QwenLM/Qwen3-TTS) | Apache-2.0 | `gen_voice.py` |

要生成的內容全部寫在 **`prompts.json`**，想改風格、改台詞、加項目都改這個檔就好。
每一項的 `name` 就是遊戲裡的音效名稱：成品 `<name>.ogg` 放進 `assets/audio/`，遊戲會自動用它取代同名的合成音（`scripts/sfx.gd`），不用改程式。
角色語音（`voice_*`）目前遊戲裡還沒有地方播，檔案做好後我再接上。

> 使用前請再看一次各模型的授權與模型權重頁面，確認生成的內容可以用在你的遊戲裡。

## 需要的電腦

- NVIDIA 顯示卡（CUDA）。建議 12 GB 以上顯示記憶體；8 GB 也可以，換成表格裡較小的模型。
- 硬碟約 40 GB（三套模型的權重，第一次執行時自動下載）
- Windows 或 Linux。三個模型各裝在**自己的** Python 環境，互相的套件版本會衝突。
- 建議先裝 [Miniconda](https://docs.conda.io/en/latest/miniconda.html) 和 [uv](https://docs.astral.sh/uv/)。

## 一、背景音樂（ACE-Step 1.5）

```bash
git clone https://github.com/ace-step/ACE-Step-1.5.git
cd ACE-Step-1.5
uv sync                      # 安裝（Windows 也可以用 start_api_server.bat）
uv run acestep-api           # 開 API 伺服器，http://localhost:8001，這個視窗保持開著
```

8 GB 以下的顯示卡，啟動前設定較小的模型（官方說明 README 的 GPU 表格）：
`ACESTEP_CONFIG_PATH=acestep-v15-turbo`、`ACESTEP_LM_MODEL_PATH=acestep-5Hz-lm-0.6B`。

另開一個視窗，到本資料夾（`tools/ai_audio`）：

```bash
python gen_music.py                      # 三首，每首 3 個候選
python gen_music.py --only music_camp    # 只重做營地音樂
```

## 二、環境音與音效（MOSS-SoundEffect v2）

```bash
conda create -n moss-sfx python=3.12 -y
conda activate moss-sfx
git clone https://github.com/OpenMOSS/MOSS-TTS.git
cd MOSS-TTS/moss_soundeffect_v2
pip install --extra-index-url https://download.pytorch.org/whl/cu128 -e ".[torch-cu128]"
```

回到本資料夾，在同一個環境裡：

```bash
python gen_sfx.py                    # 9 種環境音 + 23 種音效，每種 3 個候選
python gen_sfx.py --kind ambience    # 只做環境音
python gen_sfx.py --only splash      # 只做一個
```

第一次執行會先編譯幾分鐘，正常。

## 三、角色語音（Qwen3-TTS）

```bash
conda create -n qwen3-tts python=3.12 -y
conda activate qwen3-tts
pip install -U qwen-tts soundfile
pip install -U flash-attn --no-build-isolation   # 可省略；裝了比較省顯示記憶體
```

分兩步，先設計聲音、挑好，再念台詞：

```bash
python gen_voice.py design
#   -> out/voice_ref/merchant_1~4.wav、willow_1~4.wav：聽一聽，挑最像角色的
python gen_voice.py speak --ref merchant=out/voice_ref/merchant_3.wav --ref willow=out/voice_ref/willow_2.wav
#   -> 用挑好的聲音念完 prompts.json 裡所有台詞
```

角色的聲音描述在 `prompts.json` 的 `voices.*.design`，不滿意就改描述再跑一次 `design`。

## 四、挑選與整理成遊戲檔

每一項會產生幾個候選：`out/raw/<name>/1.wav、2.wav…`。

1. 聽一聽，把最好的那個**複製**成 `out/picked/<name>.wav`
   （例如 `out/raw/music_camp/2.wav` → `out/picked/music_camp.wav`）
2. 整理：

```bash
pip install numpy soundfile scipy
python finish.py
```

`finish.py` 會把 `out/picked/` 裡的檔案：
- 音樂、環境音、`*_loop`：尾巴和開頭交叉淡化成無縫循環，音量統一
- 音效、語音：去掉頭尾靜音、轉單聲道、音量統一
- 全部轉成 `.ogg`，放在 `out/game/`

3. 交給我：把 `out/game/` 裡的 `.ogg` 打包上傳到 GitHub Release（或直接傳給我），
   我會放進遊戲、接上語音、確認檔案大小對手機友善。
   也可以自己用 `python finish.py --copy-to ../../assets/audio` 直接放進遊戲試聽。

## 檔案大小

網頁版要下載所有聲音，請盡量控制：一首 2 分鐘的音樂約 1.5–2 MB，環境音約 300–500 KB，音效和語音各 10–50 KB。
全部做完大約 10 MB 左右。
