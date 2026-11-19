# Godot 模块与数据

Project TOWER · v0.3 · [GDD 第 8 章](../../GDD.md#godot-modules-and-data)

说明 Godot 场景、脚本模块及接口，并明确数值、表现与单局状态的归属。

使用场景组合、事件信号和集中数据配置。入口为 [`scenes/main.tscn`](../../../scenes/main.tscn)，内含竞技场、角色和弹体容器、楼层管理、音频、本地化与 UI。玩家、各类敌人和弹体各有可复用场景。

| 模块 | 相关脚本与职责 |
| --- | --- |
| 单局控制 | `run_controller.gd` 按主场景的 `Floors` 列表开始每层，执行该层的进场与清场后流程。接收 `floor_cleared` 和 UI 的 `upgrade_selected`，协调阅读、奖励和结算。 |
| 战斗 | `player.gd`、`enemy_base.gd`、`projectile.gd` 分管玩家、敌人与弹体。玩家处理输入、攻击与生命。敌人公共脚本处理受击、击退和 `died`，各敌人脚本实现行动。弹体处理阵营、轨迹、伤害及销毁。 |
| 关卡 | `floor_manager.gd` 用 `start_floor` 接收楼层定义，生成波次、判定清场并发送计数和死亡等信号。`arena.gd` 按传入的位置呈现互动点。 |
| 装备 | `reward_manager.gd` 从 `game_data.gd` 的装备池抽取互异选项。v0.3 将强化计算集中供预览与应用调用，以玩家当前属性为输入，UI 只显示计算结果。 |
| 界面和翻译 | `game_ui.gd` 组装菜单、HUD、过渡、阅读、奖励与结算。`localization_service.gd` 根据文本 ID、变量和语言设置提供翻译。 |
| 音效 | `sound_manager.gd` 接收音效事件并管理对应资源、播放与混音。战斗模块继续决定实际出手及伤害时点。 |

[`data/game_data.gd`](../../../data/game_data.gd) 管理八件装备与敌人属性。每层的波次、进场等待、清场目标和记录由 [`data/floors/`](../../../data/floors/) 中的 `FloorDefinition` 资源配置，提示和记录以 String ID 引用翻译表。角色当前 HP、冷却、移速和装备属于单局状态。基础命中使用战斗侧的扇区、距离和轨迹判定，Engineer 将绘制、粒子与音效挂在相应事件上。装备预览、预警与数值调整通过模块接口迭代。

Git 保留可运行主线。Engineer 按模块提交，集成前运行无头导入和回归，给 QA 提供可定位到提交或构建号的测试包。PM 维护素材清单与交接时间，QA 的缺陷记录关联同一构建号、设备和语言。
