# 五层关卡与叙事

Project TOWER · v0.3 · [GDD 第 4 章](../../GDD.md#floors-and-narrative)

记录五层基线波次、刷怪节奏、可选阅读触发和两处记录的双语正文。

## 4.1 楼层波次与节奏

五层复用同一竞技场与边界。生成点分布在场地边缘，优先避开玩家近身位置与已生成敌人。F1 至 F4 等当前波全部消灭再刷下一波。基线首次刷怪等待 0.65 秒，波间等待 0.9 秒。

| 楼层 | 基线波次 | 设计任务 |
| --- | --- | --- |
| F1 | 第 1 波 2 史莱姆。第 2 波 1 史莱姆、1 哥布林。 | 学习移动、瞄准、剑击与魔法。清场阅读古旧书页或直接选装。 |
| F2 | 第 1 波 2 史莱姆、1 哥布林。第 2 波 1 史莱姆、2 哥布林。 | 通过混合近战检验第一件装备的收益。清场直接选装。 |
| F3 | 第 1 波 2 哥布林、1 骷髅法师。第 2 波 1 哥布林、2 骷髅法师。 | 引入弹道压力，鼓励移动中输出。清场可读冒险者手记，再选装。 |
| F4 | 第 1 波 1 史莱姆、1 哥布林、2 骷髅法师。第 2 波 1 史莱姆、2 哥布林、1 骷髅法师。 | 组合三类敌人，检验构筑和走位。清场直接选装。 |
| F5 | 1 波，守塔精英、1 史莱姆、1 哥布林。 | 识别并躲避散射预警。击败精英即胜利，随从随结算清除。 |

QA 记录每层耗时、死亡或受伤原因、选装后的变化及阅读耗时。Engineer 优先调整波次、敌人数、HP 和生成间隔，以五层和四次奖励为结构约束。8–12 分钟是平衡目标，玩家可按自己的节奏完成一局。

<a name="optional-reading"></a>

## 4.2 可选阅读

F1、F3 在清场后显示进入奖励的 Enter 提示，玩家进入记录互动范围时出现 E 提示。阅读时锁定移动、战斗与领奖输入，关闭后可再次打开或按 Enter 领奖。记录用场景位置和本地化文本 ID 关联，无数值奖励。

**F1 古旧书页 / A Fragment of History**

古塔建成时，守塔人点亮了一盏灯。许多年后，灯仍亮着，却再无人记得最初是谁将它点燃。

When the old tower was built, its keepers lit a lamp. Years later, it still burns, though no one remembers who first lit it.

**F3 冒险者手记 / An Adventurer's Note**

第三层的回声比我快一步。我在墙边歇了一会儿，才明白独自前行，并不意味着没有人曾走过这条路。

On the third floor, my echo ran ahead of me. I rested by the wall and realized that walking alone doesn't mean no one has walked this way before.
