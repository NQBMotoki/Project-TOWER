# Project TOWER

五层俯视角动作 Roguelite 原型，使用 Godot 4.7 / GDScript。包含双语菜单、两处可选记录、四次三选一强化及最终精英战。

玩法范围、模块设计与交付计划见 [v0.3 游戏设计文档](docs/GDD.md)。

## 运行

使用 Godot 4.7 打开本目录，运行主场景；macOS 也可运行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

WASD 移动，鼠标瞄准；按住鼠标左键挥剑，右键发射魔法弹。第 1、3 层清场后靠近书页按 E 阅读，E 或 Esc 关闭；面板关闭时按 Enter 跳过或结束阅读并选择装备。菜单提供简体中文和 English (US)，语言保存在 Godot 的 `user://settings.cfg`。

## 验证

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_mvp.gd
```

敌人、装备和楼层数据位于 `data/game_data.gd`；文本源位于 `localization/game.csv`，术语和上下文位于 `docs/localization/`。运行前先导入 CSV，生成 Godot 的翻译资源。

当前角色、环境、特效均由项目代码绘制，音效由代码合成，无外部美术和音效素材。界面使用项目内的 Noto Sans SC 字体（SIL Open Font License 1.1），许可证见 `assets/fonts/OFL.txt`。平衡、典型单局时长与独立 Windows/macOS 导出包需要实际设备及试玩验证。

## 导出

`export_presets.cfg` 包含 Windows x86_64 和 macOS 通用架构预设。请在 Godot 4.7.2 中安装对应版本的官方导出模板后执行：

```sh
mkdir -p builds/windows
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" builds/windows/ProjectTOWER.exe
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" builds/ProjectTOWER-macOS.zip
```

Windows 的 `.exe` 与 `.pck` 必须放在同一目录。macOS 预设为临时签名，未经过 Apple 公证；分享给其他设备时可能需要为发布配置正式签名和公证。`builds/` 是本地构建产物，不纳入 Git。
