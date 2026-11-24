# 完全体美术与音频交接

0.3.0-dev · 2026-11-22

| 资源 | 挂点、规格与触发 |
| --- | --- |
| `assets/edition/actors.png` | 原始 1254 × 1254 透明 PNG 图集。通过 [EditionArt](../data/edition_art.gd) 读取裁切区。玩家 `HeroArt` 约 52 px，`WeaponArt` 按剑约 34 px、杖约 40 px 缩放并沿握柄枢轴转动。敌人使用各场景根节点的 `Sprite2D`，尺寸随敌人碰撞体半径。拾取、图鉴和 F10 对话前的领主也复用图集。 |
| `assets/edition/props.png` | 1448 × 1086 透明 PNG。对应 `FloorFeatures` 的 `pot_texture`、`plate_texture`、`altar_texture`、`stairs_texture`、`exit_texture`、`pearl_texture`，以及道具图标。地标名义显示尺寸约 32–96 px。F1 清场可依序看到祭坛凝珠、吸收和楼梯通行。 |
| `assets/edition/environment.png` | 1536 × 1024 PNG，六格 512 px 石材。塔前苔石、低层蓝灰旗石、精锐与中层旧驻防石、高层深紫裂石、塔顶仪式石及掩体石墙。材质裁在六边形内，装饰和照明按楼层变化。 |
| `assets/edition/grounds.png` | 1263 × 1246 透明 PNG。通过 `TowerGrounds` 的四个贴图槽读取。帐篷 144 × 124 px、火塘 56 × 54 px、主路两段各 166 × 306 px、塔门 210 × 193 px。火光动画绘制在火塘上，营地与入塔交互沿用对应 Marker2D。 |
| `assets/edition/floor_scenery.png` | 1448 × 1086 透明 PNG，10 个楼层布景加石灯和碎墙。场景围绕碰撞掩体及房间边缘放置，按 `floor_01` 至 `floor_10` 裁切。 |
| `assets/edition/title.png` | 1672 × 941 PNG 用于独立标题场景等比铺满。标题与按钮覆盖左侧背景留白。 |
| `assets/edition/ui_icons.png` | 1774 × 887 透明 PNG。由 `EditionArt` 裁切继续、新局、设置、图鉴、背包、血珠、合成、生命 8 个图标，以 18–24 px 显示。 |
| `assets/edition/portraits.png` | 1536 × 1024 PNG，六位人物的设定表预览。每格 512 px。 |
| [actor_motion.gd](../scripts/actor_motion.gd) | 根据实际速度、方向和攻击状态驱动待机、步态、前摇、挥击、收势和受击变形。消散特效在死亡事件上触发。替换贴图以原始脚点和持握轴为准。 |
| 配乐 `grounds`、`tower`、`lord`、`ending` | [retro_score.gd](../scripts/retro_score.gd) 将 Codex 生成的音序和波形合成为 22.05 kHz、16-bit、单声道循环 WAV。依次在塔前、塔内、塔顶对话与战斗及终场触发。可用 `Sound.music_assets` 覆盖同一 ID。 |
| 短音效 | [sound_manager.gd](../scripts/sound_manager.gd) 合成 22.05 kHz、16-bit、单声道短 WAV。可用 `Sound.effect_assets` 覆盖。挥击 `sword`、命中 `hit`、施法 `magic`、敌方预警 `enemy_telegraph` / `enemy_chant` / `enemy_zone_warning`、箭板 `trap_warn` / `trap_arrow`、破罐 `pot_break`、拾取 `pickup`、凝珠 `pearl_form`、吸收 `pearl_pickup`、魔化 `corrupt`。 |

图集于 2026-11-22 在本任务使用 OpenAI ImageGen 从文本生成，来源记录在此任务的生成结果。角色动作、音序和音效为本项目的 Codex 生成代码。使用生成内容依据账户适用的 OpenAI 条款。字体随包附带 [SIL Open Font License 1.1](../assets/fonts/OFL.txt)。[OpenAI Terms of Use](https://openai.com/policies/terms-of-use/#content)

回归录制优先检查低画质、镜头边缘、掩体后和连续攻击。在同一帧观察预警终点、实际弹道与命中反馈；在实际包中分别调低 Music 与 Effects 验证混音。
