# Project TOWER 本地化规范

[双语 CSV](../localization/game.csv)是文案主表。简体中文是源文，美式英语是译文。Engineer 接入字符串及变量，双语负责人确认用词和两列正文，QA 在对应构建中验证显示和交互。

## CSV 六列

| 列 | 用途 |
| --- | --- |
| `keys` | 稳定且唯一的 String ID。修改同一用途的文案沿用原 ID。需要独立翻译的新用途使用新 ID。 |
| `zh_CN` | 简体中文源文。动态内容使用 `{name}` 变量。 |
| `en_US` | 美式英语译文。变量名与源文一致，可按译文语序移动。 |
| `_category` | 主类别取 `menu`、`hud`、`transition`、`narrative`、`equipment`、`reward`、`result`、`input`。共用名称按主要用途分类。 |
| `_context` | 界面或对象、触发条件、语气及空间限制。有变量时写清每个变量的含义和示例值。书刊另记作者、年代、拾取位置和打开条件。 |
| `_status` | `placeholder` 是开发占位，`draft` 是双语待审稿，`approved` 是双方文本经双语负责人确认。任一语言正文修改后回到 `draft`。 |

用 UTF-8 保存，英文逗号分隔。字段内出现逗号、换行或双引号时用英文双引号包住，正文中的双引号写成两个。用表格工具时按文本导入并选择整行排序，保持六列顺序和 UTF-8 输出。Godot 导入前 3 列生成两份 `.translation` 文件，带下划线的 3 列供文案和 QA 使用。

## String ID

| 当前前缀 | 命名与例子 |
| --- | --- |
| `UI_` | 加上界面或功能和意图。主菜单 `UI_MENU_CONTINUE`，HUD `UI_FLOOR`，重绑 `UI_BIND_CONFLICT`，结算 `UI_VICTORY`。 |
| `ITEM_` | 使用物品 ID 和字段。以 `ITEM_U01_NAME`、`ITEM_U01_EFFECT`、`ITEM_U01_LORE`、`ITEM_U01_BADGE` 为例。材料、起始武器和药水沿用各自的物品 ID。 |
| `LORE_` | 使用记录身份或楼层加字段。书刊配对 `_TITLE` 和 `_BODY`，例如 `LORE_KIT_TITLE` / `LORE_KIT_BODY`。独立铭文沿用 `LORE_F5_DOOR`。 |
| `TIP_F<n>` | 楼层资源使用的提示，例如 `TIP_F3`。楼层标题复用 `UI_TRANSITION` 的 `{floor}`。 |
| `TRANSITION_TIP_` | 可供楼层配置选用的通用提示，例如 `TRANSITION_TIP_05`。 |

ID 使用大写英文、数字和下划线。变量名使用小写英文、数字和下划线，首字符是小写字母或下划线。功能名与类别可不同，现有 ID 以 CSV 为准。改动 ID 或变量时同时检查两种语言、上下文、引用脚本与楼层资源。

例如 `UI_TRANSITION_CONTINUE` 是过渡面板底部的单行提示，在楼层展示满 2.1 秒后出现。中英两列均含 `{next}`，上下文应写明它代表继续键并给出 Enter 示例。装备卡的 `{value}` 由游戏数据传入，翻译只处理符号、单位和语序。

## 文案交接与 LQA

1. Engineer 定义 ID、分类、出现条件和变量，开发中的临时双语文字标为 `placeholder`，并保留预期变量。
2. 双语负责人按术语表完成源文和译文，初稿标为 `draft`，两列确认后标为 `approved`。人物、领主署名、书刊标题和长文在同一轮核对。
3. Engineer 导入 CSV，提交相关 Godot 导入元数据和生成的两份翻译资源。无头检查核对两列非空、变量一致、上下文和运行时引用。候选检查拦截 `placeholder`，允许 `draft` 进入供审校的候选包。
4. QA 在所测构建中切换双语，检查塔前互动、暂停与设置、重绑、背包、清场和奖励、F5 门楣与尾声。逐屏检查按钮、字体、动态数字、长文滚动和关闭提示。问题记录附构建号、语言、ID、触发步骤和截图。 [在线 QA 验收表](https://docs.qq.com/sheet/DT2piZmt4T3VIbUFZ?tab=fmlbif)

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/test_mvp.gd -- --candidate
```

首次启动时英文系统使用美式英语，其余回退简体中文。已保存设置优先。缺译时运行时尝试简体中文并记日志，两种语言都缺失时显示可读兜底文字。

## 术语表

| 中文 | English (US) | 说明 |
| --- | --- | --- |
| 魔塔 | tower | 游戏场景 |
| 守塔者 / 守塔精英 | keeper / elite skeleton | 最终敌人；叙事与功能名称可按上下文使用 |
| 守塔人 | keeper | 点灯、记名的人；五层叙事的主语 |
| 装备 / 遗物 | gear / relic | 唯一 ID，穿戴后生效；近战、魔法、手套、饰品、护甲、鞋各一槽 |
| 背包 | bag | 持有物品、换装、阅读和合成入口 |
| 治疗药水 | Healing Potion | 蘑菇与水瓶各一份合成，恢复 30 HP |
| 快捷栏 | quick slot | 可绑定治疗药水，默认 Q |
| 剑击 | sword attack | 鼠标左键 |
| 魔法弹 | magic projectile | 鼠标右键 |
| 暴击率 | critical chance | 百分比数值；装备加成与其它属性统一使用 % |
| 冷却 | cooldown | 数值有下限，递减效果按当前值相乘 |
| 骷髅法师 | skeleton mage | 保持中距离、咏唱后发射慢速法术球的敌人 |
| 骷髅弓手 | skeleton archer | 第四类普通敌人；拉弦后射出高速箭矢 |
| 拉弦 / 换弦 | draw / restring | 弓手拉弦 0.8 秒后射出；射出后进入冷却，叙事中称「换弦」 |
| 鼓胀 / 突进 / 虚脱 | coil / lunge / recovery | 史莱姆的三段循环；虚脱期不能造成伤害 |
| 前兆 / 预警 | telegraph | 攻击前的可见警示，先于伤害判定 |
| 名册 | the roll | 记录守塔人更替的名册；五层叙事主线 |
| 埃德里克·沃恩 | Edric Vane | 领主署名，在亲笔信、研究笔记与尾声中一致 |
| 莱昂、艾妲、米拉、索伦 | Leon, Ada, Mira, Soren | 十年前的骑士、弓箭手、牧师和法师 |
| 哈伦 | Harlan | 领主下属，负责南岗，驻塔军报作者 |
| 领主亲笔信 | A Letter in the Lord's Hand | 第一层可选阅读 |
| 驻塔军报 | Garrison Dispatch | 第二层可选阅读 |
| 弓箭手的手记 | The Archer's Notes | 第三层可选阅读 |
| 法师的调查手记 | The Mage's Investigation | 第四层可选阅读 |
| 灯前留言 | A Note Left Before the Lamp | 第五层结尾阅读，结算前显示 |
| 骑士的行装册 | The Knight's Kit List | 塔前营地附近拾取 |
| 旧王国驻防令 | Garrison Order of the Old Kingdom | 塔前东侧拾取 |
| 废弃营地 | Abandoned Camp | 塔前原地查看的环境信息 |
| 牧师的祷文 | The Priest's Prayer | 第二层清场后拾取 |
| 领主的研究笔记 | The Lord's Research Notes | 第四层清场后拾取 |
