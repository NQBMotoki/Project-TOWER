# 五层关卡与叙事

Project TOWER · v0.4 · [GDD 第 4 章](../../GDD.md#floors-and-narrative)

记录五层基线波次、刷怪节奏、可选阅读触发和五处记录的双语正文。

## 4.1 楼层波次与节奏

五层复用同一竞技场与边界。生成点分布在场地边缘，优先避开玩家近身位置与已生成敌人。F1 至 F4 等当前波全部消灭再刷下一波。基线首次刷怪等待 0.65 秒，波间等待 0.9 秒；同一波内每只敌人在 0.85 秒基础上按 0.35 秒递增延迟登场（见[战斗与敌人 3.4](combat-and-enemies.md)）。

| 楼层 | 基线波次 | 设计任务 |
| --- | --- | --- |
| F1 | 第 1 波 2 史莱姆。第 2 波 1 史莱姆、1 哥布林。 | 学习移动、瞄准、剑击与魔法；学会读史莱姆的鼓胀。清场阅读名册残页或直接选装。 |
| F2 | 第 1 波 2 史莱姆、1 哥布林。第 2 波 1 史莱姆、2 哥布林。 | 通过混合近战检验第一件装备的收益，第一次面对两种前兆交替。清场阅读石匠刻记。 |
| F3 | 第 1 波 1 哥布林、1 骷髅法师、1 骷髅弓手。第 2 波 1 骷髅弓手、2 骷髅法师。 | 引入弹道压力与"必须横移"的箭矢；鼓励移动中输出。清场阅读冒险者手记。 |
| F4 | 第 1 波 1 史莱姆、1 哥布林、1 骷髅法师、1 骷髅弓手。第 2 波 1 骷髅弓手、2 哥布林、1 骷髅法师。 | 组合四类敌人，检验构筑和走位。清场阅读守则残页。 |
| F5 | 1 波，守塔精英、1 史莱姆、1 哥布林。 | 识别并躲避精英的扇形预警。击败精英即进入尾声阅读，关闭后结算胜利。 |

QA 记录每层耗时、死亡或受伤原因、选装后的变化及阅读耗时。Engineer 优先调整波次、敌人数、HP 和生成间隔，以五层和四次奖励为结构约束。8–12 分钟是平衡目标，玩家可按自己的节奏完成一局。

<a name="optional-reading"></a>

## 4.2 可选阅读

F1 至 F4 在清场后显示进入奖励的 Enter 提示，玩家进入记录互动范围时出现 E 提示。阅读时锁定移动、战斗与领奖输入，关闭后可再次打开或按 Enter 领奖。记录用场景位置和本地化文本 ID 关联，无数值奖励。

F5 不同的是**没有**自由阅读阶段：精英倒下后立即弹出「灯前留言」，按 E 或 Enter 关闭后进入结算。这一段不可跳过重启，也不与奖励选择争夺输入。

| 楼层 | 记录 | 位置 |
| --- | --- | --- |
| F1 | 古旧书页 | (905, 400) |
| F2 | 石匠刻记 | (300, 220) |
| F3 | 冒险者手记 | (905, 400) |
| F4 | 值夜守则残页 | (1000, 480) |
| F5 | 灯前留言（结算前弹出） | — |

## 4.3 五处记录正文

**F1 古旧书页 / A Fragment of History**

古塔落成那年，守塔人定下一条规矩：灯可以换，守灯的人也可以换。此后名册上每十年添一个新名字——没有一个被划掉。

In the year the tower was finished, its keeper set down one rule: the lamp may be replaced, and so may whoever keeps it. Every ten years a new name is added to the roll, and not one has ever been struck out.

**F2 石匠刻记 / A Stonemason's Mark**

我替塔补过三十七级台阶。每年磨穿的总是同一级，图纸上只写着：此处需修，不必问。今年儿子接了手，他说那一级，上去时总比下来时矮一寸。

I have mended thirty-seven steps in this tower. Every year it is the same one worn through, and the drawing says only this: repair it here, ask nothing. This year my son took over the work. He says that step always sits an inch lower going up than coming down.

**F3 冒险者手记 / An Adventurer's Note**

回声总比我快半步，像有人在前头替我数台阶。三层往上，墙上开始有箭孔，孔都朝里开。我把火把插进一个孔里，坐下歇脚，才看清孔边还有更旧的焦痕。

My echo always runs half a step ahead of me, as if someone up there counts the steps for me. From the third floor up the walls carry arrow slits, every one of them facing inward. I wedged my torch into one and sat down to rest, and only then saw the older scorch marks beside it.

**F4 值夜守则残页 / A Torn Page of the Warden's Rules**

守则·四条：不要追着声音跑。七条：弓手只在换弦时露破绽，箭在弦上时没有。十七条：若有人从下面上来，先点灯，再问名字。最后一条被人撕去了，撕口还很新。

Warden's rules, article four: never run toward a sound. Article seven: an archer is open only while restringing, never while the arrow is set. Article seventeen: if someone climbs up from below, light the lamp first, ask the name after. The final article has been torn away, and the tear is still fresh.

**F5 灯前留言 / A Note Left Before the Lamp**

灯芯我一共剪短过十七次。名册上每一个名字都是我写下的，包括你的——在你进塔之前。你还站着，说明我写得早了些。这一页翻过去吧，灯交给下一个愿意上楼的人。

I have trimmed this wick short seventeen times. Every name in the roll was written by my hand, yours among them, before you ever came in. You are still standing, so I wrote it early. Turn the page. The lamp belongs now to whoever is willing to climb.

## 4.4 层间提示

F1 至 F5 各有一条专属提示，由 `GameData.FLOOR_TIPS` 按层取用；F5 在提示下方追加门楣刻字 `LORE_F5_DOOR`。通用 `TRANSITION_TIP_*` 保留为兜底。

| 楼层 | 提示 |
| --- | --- |
| F1 | 剑与魔法都朝鼠标所指的方向。史莱姆会先鼓起身体，才扑出来。 |
| F2 | 哥布林会在动手前停住。它停住的那一瞬，就是你要动的时候。 |
| F3 | 墙上的箭孔都朝里。弓手拉弦时不必急，弦响之后才有空隙。 |
| F4 | 法师咏唱时不要靠近，弓手拉弦时不要跑直线。 |
| F5 | 守塔人的灯在塔顶。他总先照亮自己要打的地方。 |

**F5 门楣刻字**

门楣上有几道很浅的划痕，像用指甲刻的：若你读到这里，请替我把灯芯剪短一寸。

Shallow scratches cross the lintel, as if cut with a fingernail: if you have read this far, trim the wick an inch for me.
