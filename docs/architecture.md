# Project TOWER 技术架构

完全体开发候选 0.3.0-dev · 基线 0.2.1（`031876f`） · Godot 4.7.2

[主场景](../scenes/main.tscn)组装塔前、楼层、角色、掉落、机关、音效和界面。`Main.floors` 按 F1–F10 顺序安装。关卡数据与控制器负责流程，界面和素材响应玩法状态。

| 模块 | 入口与职责 |
| --- | --- |
| 单局 | [run_controller.gd](../scripts/run_controller.gd) 管理开场、塔前、楼层转场、战斗、清场、F10 对话、终场和结算。清场开放通行。走进楼梯或终点才推进。 |
| 楼层与世界 | [floor_manager.gd](../scripts/floor_manager.gd) 按资源刷波和发出清场事件。[arena_layout.gd](../scripts/arena_layout.gd) 为走路、寻路、弹体和拾取共用六边形边界与掩体。[floor_features.gd](../scripts/floor_features.gd) 管理瓶罐、箭板、地标和机关弹体。 |
| 战斗与动作 | [player.gd](../scripts/player.gd) 按当前武器发起攻击。[enemy_base.gd](../scripts/enemy_base.gd) 及派生脚本按各自出招时序执行。[actor_motion.gd](../scripts/actor_motion.gd) 用移动和战斗状态驱动美术变换。射线、范围和碰撞独立在玩法层结算。 |
| 物品、魔化和图鉴 | [run_inventory.gd](../scripts/run_inventory.gd) 管理背包、单武器槽、耗材、合成、血珠和投入等级。[player_stats.gd](../data/player_stats.gd) 供战斗、预览和存档使用同一套数值。[run_codex.gd](../scripts/run_codex.gd) 保存发现和已读。 |
| 界面、语言与键位 | [game_ui.gd](../scripts/game_ui.gd) 管理界面栈和提示。[inventory_panel.gd](../scripts/inventory_panel.gd) 实现四页入口。[localization_service.gd](../scripts/localization_service.gd) 按 String ID 读取双语资源并维护可重绑输入。 |
| 音频 | [sound_manager.gd](../scripts/sound_manager.gd) 通过事件 ID 播放音效，协调单播放器配乐切换和 Master、Effects、Music 总线。 |

## 设定与可复现布局

维护 [Excel 设定表](../data/design/Project-TOWER-设定表.xlsx)的「楼层」和「参数」两页。运行 [导出器](../tools/export_settings.py)生成 `data/edition_settings.gd` 与十份 `data/floors/` 资源。资源携带稳定实体 ID、机制 ID 和文本引用。图鉴的招式时长使用战斗同一参数。文本由 [game.csv](../localization/game.csv) 维护。

单局种子派生布局、敌人出生顺序、敌方掉落和场景道具。[floor_topology.gd](../data/floor_topology.gd) 给各层定义通道和掩体结构，种子改变局部掩体和布置。生成与恢复均校验掩体和关键点的可达性。敌人掉落在开波前按刷怪顺序预定，击杀顺序不改变分配。六边形地表、石墙和故事装饰通过绘制层接入。碰撞、陷阱触发域、地图状态与美术资源尺寸独立。

## 存档契约

| 文件 | 恢复规则 |
| --- | --- |
| `user://tower_complete.save` 和 `.bak` | 版本 2，持久化种子、阶段、楼层、波次、预定掉落、玩家位置与生命、独立武器计时、背包、魔化、祭坛及机关。使用 SHA-256 校验，先复读临时文件，再轮换同一局的备份并替换主档。 |
| 战斗阶段 | 波中回到本波起点。恢复波首的在场掉落、瓶罐、箭板状态及在途机关箭。波间与自由探索保存已经发生的动作。 |
| 塔顶阶段 | 未完成的对话从第一句恢复。结束对话后恢复战斗检查点。击败领主后恢复可探索现场与开放终点。已经走进终点则恢复终场。 |
| `user://tower_codex.cfg` | 跨局发现、敌人遭遇和已读记录。独立于当局资源，战斗回退后仍可查阅。 |
| `user://settings.cfg` | 保留语言、画质、按键及三组音量。输入冲突时拒绝新设置，加载到互相冲突的绑定时使用默认键位。 |

0.2.1 的五层存档与完全体不兼容。胜负结算清理完全体主档及备份。新局有可续档时要求确认覆盖。

验证命令与导出方式见 [README](../README.md#验证与导出)。
