@echo off
rem 把 AI 做的 mp4 轉成遊戲用的 .ogv（需要已安裝 ffmpeg）
rem 把 dash.mp4 side_dash.mp4 leap.mp4 rock_dive.mp4 rage.mp4 rally.mp4 weed.mp4 放在這個檔案旁邊再雙擊執行
for %%n in (dash side_dash leap rock_dive rage rally weed) do (
  if exist %%n.mp4 ffmpeg -y -i %%n.mp4 -vf "scale=576:324" -c:v libtheora -q:v 7 -an %%n.ogv
)
pause
