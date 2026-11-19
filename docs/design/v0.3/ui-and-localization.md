# 界面与本地化

Project TOWER · v0.3 · [GDD 第 6 章](../../GDD.md#ui-and-localization)

记录界面与双语文本规范。遗物短句和层间提示全文收录于[附录](#bilingual-narrative)。

## 6.1 界面内容

| 界面 | 玩家可见信息与操作 |
| --- | --- |
| 主菜单 | 开始、退出、键鼠操作说明和「简体中文／English (US)」入口。切换后立即刷新，清楚标示所选语言。 |
| 战斗 HUD | 左上生命条及当前/最大 HP，右上楼层、波次和剩余敌人，下方魔法就绪或冷却秒数与已获装备。危险与当前操作优先。 |
| 安全阅读 | 清场后显示 Enter 提示，靠近记录时显示 E 提示。阅读面板含标题、正文和关闭按键。 |
| 奖励面板 | 三张可点选卡片。图标、强化说明、预览和短叙事分区，选择操作清楚可见。 |
| 层间过渡 | 显示下一层和一条已翻译的玩法提示或背景短句。 |
| 胜负结算 | 显示胜负、到达层数、击杀数、本局用时和装备。提供「重新开始」和「返回主菜单」。 |

沿用 1280 × 720 设计视口，双语走查覆盖默认窗口和较小窗口。界面组件统一按钮、面板和文字层级，英文长文可完整换行。阅读与奖励文字在有特效或背景装饰时仍应清楚可读。

## 6.2 双语文本管理

玩家语言为简体中文（zh-CN）及美式英语（en-US）。首启匹配系统语言，英文环境选 en-US，其余回退简体中文。已保存的选择优先，设置存于 `user://settings.cfg`。切换后更新翻译服务和当前菜单，后续界面使用新语言。

[`localization/game.csv`](../../../localization/game.csv) 使用 UTF-8，按稳定 ID 保存简体中文源文、美式英语译文、分类、上下文和审校状态。Godot 导入两份翻译资源。装备名称、效果和短句各用独立 ID，数值来自配置。同一条文本的变量名在两种语言中一致。缺项回退简体中文并记录，双语均缺失时显示可读的兜底提示。

Engineer 定义 ID、显示条件和变量，双语文案负责人撰写并确认文案，QA 核对术语、变量、字体、换行及候选包内显示。参见[本地化工作流](../../localization/context.md)。两端游戏包包含双语资源、Noto Sans SC 字体及其许可证。楼层记录的设计文案见[《五层关卡与叙事》](floors-and-narrative.md)，遗物与过渡短文见本文[附录](#bilingual-narrative)。

<a name="bilingual-narrative"></a>

## 附录 双语叙事文本

### 遗物短句

| 装备 | 简体中文 | 美式英语 |
| --- | --- | --- |
| 锋利长剑 | 剑刃上的细小缺口，是每一次挥砍留下的记号。 | Tiny nicks along the blade mark every swing. |
| 疾风手套 | 轻薄的手套让持剑的手如风般敏捷。 | These light gloves let a sword hand move as swiftly as the wind. |
| 烈焰法杖 | 杖尖残留的温度，像一团不肯熄灭的余烬。 | Warmth lingers at the tip, like an ember that refuses to die. |
| 奥术戒指 | 戒面刻着一圈细密符文，微光随呼吸起伏。 | Fine runes circle the ring, their glow rising and falling with each breath. |
| 幸运徽章 | 磨损的徽章被无数次攥紧，仿佛能为旅人留住好运。 | Worn smooth by countless anxious grips, this emblem seems to hold a traveler's luck. |
| 吸血剑刃 | 暗红的纹路沿刃脊延伸，仿佛仍在脉动。 | Dark red lines run along the blade, as if they still pulse. |
| 骑士铠甲 | 铠甲上布满修补痕迹，却依旧可靠。 | Repairs cover this armor, but it remains dependable. |
| 迅捷长靴 | 鞋底的磨痕，记录着一位旅人走过的漫长道路。 | The worn soles tell of the long road a traveler once walked. |

### 层间提示和背景短句

| 简体中文 | 美式英语 |
| --- | --- |
| 剑击和魔法弹都朝鼠标所指的方向发出。 | Your sword and magic projectiles aim toward the mouse cursor. |
| 第 1 至第 4 层结束后，从三件装备中选择一件。 | After floors 1 through 4, choose one of three upgrades. |
| 塔中的遗物，仍保留着曾经到访者的痕迹。 | Relics in the tower still bear traces of those who came before. |
| 哥布林攻击前会停下并发出预警。 | Goblins stop and telegraph their attacks before striking. |
| 同一种装备可以重复获得，效果会叠加。 | The same upgrade can appear again; its effects stack. |
