# Project TOWER 技术架构

游戏版本 0.2.0 · 开发候选 · Godot 4.7.2 / GDScript

[主场景](../scenes/main.tscn)把塔前、竞技场、交互物、角色、弹体、楼层管理、界面、音效和本地化服务组装到 `Main`。控制器负责阶段和协调，资源定义关卡与数值，界面和音效按状态或事件呈现。

## 模块与接口

| 模块 | 入口 | 职责 |
| --- | --- | --- |
| 单局 | [run_controller.gd](../scripts/run_controller.gd) | 按 `Main.floors` 推进塔前、过渡、战斗、清场探索、奖励、尾声与结算。接收楼层和界面信号，协调玩家、物品、布局、存档与暂停。 |
| 塔前与过场 | [scenes/world](../scenes/world/) | `tower_grounds.tscn` 放置塔门、营地和拾取坐标。拾取物、骑士幽灵和楼层标题演出有独立场景和可替换的 `Sprite2D`。控制器依然负责互动、时序与锁定输入。 |
| 楼层与布局 | [floor_manager.gd](../scripts/floor_manager.gd)、[arena_layout.gd](../scripts/arena_layout.gd)、[arena.gd](../scripts/arena.gd) | 生成波次和确定清场，发出 `before_wave`、`between_waves`、`enemy_killed`、`floor_cleared` 等信号。同一份掩体布局用于绘制、运动、视线和 AStar2D 绕行。 |
| 战斗 | [player.gd](../scripts/player.gd)、[enemy_base.gd](../scripts/enemy_base.gd)、[projectile.gd](../scripts/projectile.gd) | 分管玩家攻击、生命与受伤，敌人各自的出招和弹体轨迹。派生敌人脚本定义动作，碰撞与伤害在玩法侧结算。 |
| 物品、奖励和装备 | [run_inventory.gd](../scripts/run_inventory.gd)、[reward_manager.gd](../scripts/reward_manager.gd) | 背包维护唯一装备／书刊、材料堆叠、槽位和已读状态。奖励管理器提供三选一、掉落及物品池排除规则。玩家按当前槽位重算属性并保留攻击计时。 |
| 保存与恢复 | [run_save.gd](../scripts/run_save.gd) | 主档、临时文件、备份、格式检查与恢复数据校验。控制器决定在何时、按哪个阶段保存。 |
| UI 与设置 | [game_ui.gd](../scripts/game_ui.gd)、[settings_panel.gd](../scripts/settings_panel.gd)、[inventory_panel.gd](../scripts/inventory_panel.gd) | 组装主菜单、HUD、面板、奖励卡和结算。界面通过信号请求选择或换装。控制器通过顶层面板状态同步树暂停。 |
| 本地化和输入 | [localization_service.gd](../scripts/localization_service.gd) | 加载翻译资源、按 ID 和参数返回文字，保存偏好，重绑 InputMap，并在 HUD 等界面重建按键提示。 |
| 音频 | [sound_manager.gd](../scripts/sound_manager.gd) | 通过 `sound_requested(kind)` 或 `play(kind)` 触发合成音，音效走 Effects 再进 Master 总线。设置试听允许在暂停时播放。 |

## 数据归属与随机性

- [FloorDefinition](../data/floor_definition.gd) 定义提示、门楣、确认开战、波次、指定清场目标、掩体数量、中央空区、保底拾取与尾声。五个 [楼层资源](../data/floors/) 按 `Main.floors` 顺序安装。书刊和提示只写 ID，正文来自双语 CSV。
- [game_data.gd](../data/game_data.gd) 维护敌人参数、八件装备、槽位、起始武器、可堆叠物、奖励补位和药水恢复量。界面从同一数值构造 `{value}`。战斗参数发生变化时核对实际出招、可读性和显示。
- `ArenaLayout` 保护玩家起点、固定刷新点和清场拾取位置，生成和恢复均检查有效性及连通性。敌人的体积与弹体半径参与碰撞。F5 使用 `keep_center_open` 为精英战保留中央空间。
- 控制器用单局种子派生布局、波次掉落和奖励随机数。开战前按刷怪顺序分配掉落并预留唯一装备，击杀顺序不会重抽这批掉落。奖励候选会保存。设计和复现时记录所测构建与可用种子。

## 存档契约

| 项目 | 约定 |
| --- | --- |
| 设置 | `user://settings.cfg`，保存语言、画质、总音量、音效音量和单键／鼠标绑定。首次按系统语言选中英，已保存设置优先。输入冲突会拒绝写入，加载时发现冲突则恢复默认。 |
| 单局 | `user://run.save`，同目录备份 `run.save.bak`。格式版本为 1，带标识与 SHA-256 摘要。先写并复读临时文件，按同一局种子轮换可用备份，再替换主档。 |
| 持久化内容 | 阶段、楼层、种子、波次、预定掉落、掩体布局、地面物品、待选奖励、背包与已读、玩家位置／HP／冷却、用时、击杀与幽灵演出状态。 |
| 阶段恢复 | 塔前、揭示、清场、领奖和尾声恢复到所保存阶段。未完成的幽灵演出可从塔门重新触发。战斗中的保存使用开战前快照，波间使用保留上一波成果的快照。 |
| 异常 | 先校验主档结构、阶段及数据，再尝试备份。写入失败显示提示并保留返回或退出前的界面。胜负结算使本局主档、备份和临时文件失效。 |

## 验证入口

使用 [tests/test_mvp.gd](../tests/test_mvp.gd) 检查场景与双语资源、战斗判定、布局连通、背包与掉落、五层流程以及异常存档。先跑无头导入，再跑候选回归。独立包使用两端预设导出，启动、输入、画面、听感、真人流程与签名按实际提交包验收。命令见 [README](../README.md)。
