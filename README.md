# Project TOWER

五层俯视角动作 Roguelite，使用 Godot 4.7.2 / GDScript。玩家从塔前取剑与法杖，进塔战斗、搜集与换装，击败守塔者后阅读尾声。界面与叙事支持简体中文和美式英语。

当前开发候选的 macOS 导出预设标记为 **0.2.0**。已发布的测试包按对应标签取用。 [GitHub Releases](https://github.com/NQBMotoki/Project-TOWER/releases)

## 启动与操作

用 Godot 4.7.2 打开项目并运行主场景，或在项目根目录执行以下命令。macOS 如未将 `godot` 加入 PATH，可使用 `/Applications/Godot.app/Contents/MacOS/Godot`。

```sh
godot --path .
```

| 默认操作 | 用途 |
| --- | --- |
| WASD、鼠标 | 移动与瞄准 |
| 鼠标左键、右键 | 近战与魔法 |
| E | 拾取、查看营地、通过塔门、关闭阅读 |
| B、Q | 打开背包、使用已绑定到快捷栏的药水 |
| Enter | 确认楼层提示，或在清场探索后进入奖励或尾声 |
| Esc | 暂停或关闭最上层面板 |

首次玩时，先拾取塔门两侧的剑和法杖，两件会自动装备。缺武器就尝试进门时，蓝色骑士幽灵会指路。每层柱子和碎墙阻挡移动、弹体和隔墙近战。清场后可以先拾取地上的物品和书刊。前四层各领一件奖励，装备从背包穿戴后生效。塔前和第一层清场区分别提供蘑菇和水瓶各一份，在背包的合成面板可制成一瓶恢复 30 HP 的药水。

## 设置与续档

主菜单和暂停菜单共用设置。画质、总音量、音效音量、界面语言及键鼠绑定保存在 `user://settings.cfg`。两档画质均显示战斗预警和入塔、楼层演出。Esc 固定，其余显示在操控设置中的动作可重绑。

用暂停菜单的保存并返回主菜单，或正常关闭游戏窗口。主菜单有有效存档时可继续。塔前、楼层提示、清场探索、领奖和尾声可从对应阶段恢复。战斗续档回到本波开战前，本波的用时、受伤、击杀、拾取、换装、合成和消耗一并回退。波间保存保留已完成波次的成果。主档不可用时游戏尝试读取备份。死亡和胜利结算清除本局存档与备份。

## 文档

- [游戏设计文档](docs/GDD.md)
- [技术架构](docs/architecture.md)
- [本地化规范](docs/localization.md)
- [世界观设定](docs/worldbuilding.md)

排期、QA、模块细则与交付材料通过团队在线目录维护。本地待同步稿位于项目旁的 `Project-TOWER-OnlineDocsCandidates`。 [在线文档目录](https://docs.qq.com/sheet/DT2t0WEdBd3RGcFFz?tab=BB08J2)

## 验证与导出

从项目根目录导入资源，然后运行回归。日常开发可用普通回归。候选包用 `--candidate` 检查遗留占位文案。

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/test_mvp.gd
godot --headless --path . --script res://tests/test_mvp.gd -- --candidate
```

使用 [导出预设](export_presets.cfg) 与 Godot 4.7.2 导出模板。正式组包前核对源码、导出元数据、包名和验收版本。

```sh
mkdir -p builds/windows
godot --headless --path . --export-release "Windows Desktop" builds/windows/ProjectTOWER.exe
godot --headless --path . --export-release "macOS" builds/ProjectTOWER-macOS.zip
```

Windows 的 `.exe` 与 `.pck` 放在同一目录。macOS 预设使用临时签名，交付前记录公证状态与目标设备的启动结果。角色、场景与特效由项目绘制，音效由代码合成。随包附 Noto Sans SC 的 [SIL Open Font License 1.1](assets/fonts/OFL.txt)。构建产物放在 `builds/`，QA 对实际候选包记录独立启动、操作、完整通关和听感。
