#!/bin/sh
# 把 AI 做的 mp4 轉成遊戲用的 .ogv（Ogg Theora，576x324，無音軌）
# 用法：把 dash.mp4 side_dash.mp4 leap.mp4 rock_dive.mp4 rage.mp4 rally.mp4 weed.mp4 放在這個腳本旁邊，
#       執行 sh convert_fight_clips.sh，產生的 .ogv 放進專案的 assets/fight_moves/
for n in dash side_dash leap rock_dive rage rally weed; do
  [ -f "$n.mp4" ] && ffmpeg -y -i "$n.mp4" -vf "scale=576:324" -c:v libtheora -q:v 7 -an "$n.ogv"
done
