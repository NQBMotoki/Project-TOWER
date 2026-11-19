# 本地化工作流与上下文

[双语 CSV](../../localization/game.csv) 是文案主表。简体中文为源文，美式英语为译文。每条记录的类别、上下文和审校状态跟随同一个 String ID。[术语表](glossary.md) 用于统一用词。

## 填写字符串

保持 UTF-8 和 CSV 引号规则。Godot 根据 `keys`、`zh_CN` 和 `en_US` 生成双语资源，以下划线开头的列随 CSV 供编辑和审校。

| 列 | 填写方式 |
| --- | --- |
| `keys` | 稳定且唯一的 String ID，如 `LORE_F5_DOOR`。同一用途的文案改写沿用该 ID。新用途若需要独立翻译，可新增 ID。 |
| `zh_CN` | 简体中文源文。参数使用 `{name}`，例如 `{next}`。 |
| `en_US` | 美式英语译文。变量名与源文一致，可按英文语序移动。 |
| `_category` | 主类别，使用 `menu`、`hud`、`transition`、`narrative`、`equipment`、`reward`、`result` 或 `input`。同一个装备名称可以在多个界面使用，其主类别为 `equipment`。 |
| `_context` | 写明界面或对象、触发条件，以及适用的语气、空间与换行限制。有变量时注明 `{name}` 的含义并给出示例值。 |
| `_status` | `placeholder` 用于开发期间的临时文字，`draft` 用于待审的双语稿，`approved` 用于双语文案负责人已确认的文本。源文或译文修改后回到 `draft`。 |

例如，`UI_TRANSITION_CONTINUE` 属于 `transition`，在启用停等的楼层过渡面板底部显示。`{next}` 是继续按键，例如 Enter，提示占一行。`LORE_F5_DOOR` 属于 `narrative`，需要用可换行的私人嘱托口吻，填在第五层资源的 `Entry Note Key`。

## 交接与验收

1. **Content Request** 由 Engineer 创建 ID、类别和上下文，注明出现条件、变量示例以及到达画面的方式。临时双语文案沿用该 ID 和预期变量，标为 `placeholder`。
2. **Writing → Localization** 将简体中文源文和美式英语译文写入同一行。参考术语表，完成初稿后标为 `draft`。双语文案负责人确认两列后标为 `approved`。
3. **Integration** 由 Engineer 导入 CSV 并运行回归。候选包导出前使用 `--candidate`，检查有效分类、上下文、双语非空、楼层与界面引用、变量匹配和遗留占位稿。审校构建可以带 `draft` 条目。
4. **LQA** 由 QA 在对应构建切换两种语言。验证前四层的阅读、关闭或跳过和领奖，以及第五层的门楣停等、继续开战、精英清场、尾声和胜利结算。检查英文长文本、按键提示、字体和装备数值，在问题记录附构建号、语言、String ID、复现步骤和截图。文案修订后重新走双语确认与复验。

从项目根目录依次运行导入和候选包检查。使用普通回归命令时可验证带合规占位稿的开发版本。

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/test_mvp.gd -- --candidate
```
