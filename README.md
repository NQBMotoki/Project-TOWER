# Project TOWER

十层俯视角动作 Roguelite，使用 Godot 4.7.2 / GDScript。玩家在塔前装备武器，进塔战斗、搜集和魔化，击败塔顶领主后亲自走入终点。界面与文稿支持简体中文和美式英语。

当前完全体候选为 **0.3.0-dev**，实现基线为 **0.2.1**（`031876f`）。[GitHub Releases](https://github.com/NQBMotoki/Project-TOWER/releases)

## 启动与操作

用 Godot 4.7.2 打开项目并运行主场景，或在项目根目录执行以下命令。macOS 如未将 `godot` 加入 PATH，可使用 `/Applications/Godot.app/Contents/MacOS/Godot`。

```sh
godot --path .
```

| 默认操作 | 用途 |
| --- | --- |
| WASD、鼠标 | 移动与瞄准 |
| 鼠标左键 | 以当前武器攻击 |
| E | 互动、吸收血珠、推进对话或关闭阅读 |
| B、Q | 打开背包、使用已设到快捷栏的药水 |
| Enter | 推进塔顶对话 |
| Esc | 暂停或关闭当前面板 |

走近地面物品即可拾取。塔前拿起任意一把武器后可按 E 进塔。F1–F9 清场后可搜集、领珠、换装、魔化，再走上楼梯。F10 击败领主后，走进终点触发胜利。背包分为背包、魔化、合成与图鉴四页。

## 设置与续档

设置保存语言、画质、按键、总音量、配乐和音效音量。Esc 固定。暂停菜单的保存并返回主菜单，或正常关闭窗口，均可保留当前局。波中从本波初始状态恢复。波间、清场探索或转场从保存时的阶段继续。损坏的主档可尝试从同一局备份恢复。主菜单图鉴保留跨局发现与已读记录。0.2.1 五层存档与完全体不兼容。

## 文档

- [游戏设计文档](docs/GDD.md)
- [技术架构](docs/architecture.md)
- [本地化规范](docs/localization.md)
- [世界观设定](docs/worldbuilding.md)
- [Excel 设定表](data/design/Project-TOWER-设定表.xlsx)
- [美术和音频资产交接](docs/asset-handoff.md)

排期、QA、模块细则与交付材料通过团队在线目录维护。本地待同步稿位于项目旁的 `Project-TOWER-OnlineDocsCandidates`。 [在线文档目录](https://docs.qq.com/sheet/DT2t0WEdBd3RGcFFz?tab=BB08J2)

## 验证与导出

从项目根目录导入资源，然后运行回归。日常开发可用普通回归。候选包用 `--candidate` 检查遗留占位文案。

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/test_mvp.gd
godot --headless --path . --script res://tests/test_mvp.gd -- --candidate
godot --headless --path . --script res://tests/test_settings.gd
python3 tools/export_settings.py data/design/Project-TOWER-设定表.xlsx --check
```

使用 [导出预设](export_presets.cfg) 与 Godot 4.7.2 导出模板。正式组包前核对源码、导出元数据、包名和验收版本。

```sh
mkdir -p builds/windows
godot --headless --path . --export-release "Windows Desktop" builds/windows/ProjectTOWER.exe
godot --headless --path . --export-release "macOS" builds/ProjectTOWER-macOS.zip
```

Windows 的 `.exe` 与 `.pck` 放在同一目录。macOS 预设使用临时签名，交付前记录公证状态与目标设备的启动结果。轻像素贴图来自 ImageGen，动作由玩法状态驱动，配乐与音效由代码合成。随包附 Noto Sans SC 的 [SIL Open Font License 1.1](assets/fonts/OFL.txt)。构建产物放在 `builds/`，QA 对实际候选包记录独立启动、操作、完整通关和听感。

## 许可

Project TOWER 的原创代码、项目拥有授权权利的美术和音频、文稿及文档采用 [MIT 许可证](LICENSE)。第三方内容适用各自的许可证，包括 [Noto Sans SC（SIL OFL 1.1）](assets/fonts/OFL.txt)和 [Godot AI 插件（MIT）](addons/godot_ai/LICENSE)。素材来源见[美术和音频资产交接](docs/asset-handoff.md)。
