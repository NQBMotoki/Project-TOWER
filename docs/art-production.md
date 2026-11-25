# 视听改版美术制作与交接

2026-11-24 视听候选版的运行资源在 `assets/upgrade/`，初版共有 15 张角色图集和 24 张场景、地图及书册纹理。每张 PNG 配有 Godot 的纹理导入设置。初版图集中 2,068 个 64 × 64 画格均有可见像素，每格边缘至少留一个透明像素。[运行选帧接口](../data/upgrade_art.gd) · [0.3.0-dev 原版美术出处](asset-handoff.md)

## 角色与握点

画格脚点为原生像素 (32, 56)。用居中 Sprite2D 绘制原尺寸画格时，中心放在脚点上方 24 像素。主角正面头部、敌人面部及冠饰取自项目原有角色图集。背面、衣褶、肩、肘、膝、承重脚和武器手由绘制脚本逐姿势绘制。方向先决定身体侧面宽度、前后肢遮挡与眼睛朝向，再按步态移动脚，左右对应方向使用镜像。史莱姆沿身体高度改变鼓起宽度，幽灵的下摆在躯干换向后继续摆动。[角色原图](../assets/edition/actors.png) · [像素画稿与装配工具](../tools/art/paint_actors.py)

| 文件或角色 | 方向与动作 | 接入 |
| --- | --- | --- |
| `hero`、`hero_sword`、`hero_staff` | 南、东南、东、东北、北、西北、西、西南。每方向 28 格，包括待机 2 格、步行 6 格、前摇 3 格、出手 3 格、收势 3 格、受击 2 格、消散 5 格、受惊 4 格 | 移动取实际速度方向，攻击取玩法锁定方向。各持装的手位分别从画稿导出，以脚点为原点。剑、杖保持独立着色与瞄准。 |
| `goblin`、`skeleton`、`archer`、`elite`、`lord` 及 3 个对应腐蚀人形 | 南、东、北、西。铠甲、骨架、斗篷和侧面轮廓按种类区分，步行循环含两次交替接地。 | 基础动作共 24 格/向。弓手补近战，腐蚀弓手再补连射，腐蚀哥布林补冲刺，腐蚀骷髅补术区，精锐补齐射，领主补齐射、术区和近战。每种附加招式含前摇、出手、收势各 3 格。 |
| `slime`、`corrupted_slime`、`ghost` | 四向。史莱姆压低、蓄力、起跳、腾空、触地与摊开。幽灵的轮廓与下摆分相位移动。 | 源图来自相应旧版角色。出手、受击及分块飘散与移动循环分别取格。 |
| `knight` | 显形、指剑、指杖、消散各 4 格，合计 16 格 | 头盔、羽饰、肩甲、披风及手指按营地像素尺度绘制。两段手势分别向屏幕左、右伸展。指向动作达到末格后由演出定姿。 |

精锐骨甲、领主皇冠和主角围巾沿用角色原稿的设计。营地骑士、手臂与武器姿势、背向造型和步态关键帧出自本次项目绘制。握点数组顺序随图集列顺序，`UpgradeArt.grip(id, direction, state, index)` 返回相对脚点的向量。更改手部姿势后同时重建图集和握点数据。[握点数据](../data/upgrade_grips.gd)

### 两场首领战

11 月 25 日改版在既有精锐和领主的角色设计上追加逐帧图。贴图均由 [角色绘制脚本](../tools/art/paint_actors.py) 生成，使用原有头部剪影和配色。角色仍以每格 (32, 56) 为脚点，由 `UpgradeArt.frame` 按四向和招式读取。特殊姿态独立存放，便于在战斗与演出共用。

| 文件 | 规格 | 挂点与触发 |
| --- | --- | --- |
| `elite.png` | 3264 × 256，每向 51 格 | F5 基础行为之外包含骨矛齐射、双拍横扫及冲刺。当前招式阶段与预警同时驱动摆刃、持戟和收势。 |
| `elite_poses.png` | 640 × 256，每向 10 格 | `assemble` 4 格在登场前摇拼合骨甲，`phase` 4 格用于 55% 生命的换式，`stance` 2 格表现换式后的待机。失败消散使用主图集内的下跪动作。 |
| `lord.png` | 3264 × 256，每向 51 格 | F10 横扫、扇形魔弹与地咒的前摇、出手、收势共享现有受击和漂行姿态。 |
| `lord_poses.png` | 1088 × 256，每向 17 格 | `phase` 4 格取用于两次换式，`stance` 和 `final` 各 2 格为后两阶段待机，`gesture` 4 格用于气泡演出，`defeated` 5 格表现身体下沉、皇冠落地及抬腕指向。 |

扇区边缘与弹道预警使用共享障碍裁剪。实体魔弹拖尾根据已走过的路径绘制，史莱姆、冲锋怪物和幽灵的痕迹按实际位移取样。预警和地咒由独立的无光照绘制层显示，避免暗处遮蔽方向。 [怪物绘制](../scripts/enemy_base.gd) · [地面咒印](../scripts/enemy_ground_hazard.gd) · [弹体](../scripts/projectile.gd)

## 建筑、地图与双页书册

| 资源 | 原生规格 | 画面与坐标 |
| --- | --- | --- |
| `stairs_closed`、`stairs_open`、`stairs_front` | 各 192 × 128 | 北墙的灰紫岩块以祭坛的缺口、暖灰受光和暗色接缝为参照。背图绘有墙肩、门洞、台阶和地面。关闭时加锻铁闸，开放时光线落在较高的踏面。前图只取拱圈与双柱的遮挡像素。三图共享左上角 (544, 28)，首级接近交互锚点 (640, 126)。 |
| `floor_01` 至 `floor_10`、`wall` | 每层地砖 384 × 288，墙 128 × 96 | 地砖按随机种子逐块绘制错缝、崩角和左上方受光的边缘。矿物细纹来自原项目的石材原图。低层偏蓝灰，驻防层偏暖，F8–F9 有少量侵蚀纹，F10 有仪式石刻。游戏按 384 × 288 世界像素重复地砖。 |
| `lamp`、`rubble`、`pot` | 48 × 72、64 × 44、52 × 54 | 砂岩灯座、铜制火篮、碎石、陶体受光分别绘制。接地阴影位于各图下缘。 |
| `plate`、`plate_armed`、`launcher`、`launcher_armed` | 触发板 60 × 44，出箭口 48 × 38 | 警戒状态抬起板边并点亮方向纹，出箭口按向右的基准绘制，游戏按实际弹道旋转。 |
| `tower_cutaway` | 640 × 360 | 山谷和塔身分别生成。按十个实绘房间分段校正竖向位置，首层至顶层依次对应 (345, 296) 到 (345, 71)，每层上移 25 像素。转场从原图 x=155 起裁宽 330，全高保留。灯点通过同一裁区映射。 |
| `book_spread`、`codex_spread` | 各 640 × 360 | 装备册用冷色布纹、经线、金属包角和缝线勾出双页。手稿用暖灰纸色和角落铅笔排线。书页留出正文和插画位置。可读文字与焦点由游戏 UI 绘制，图标与条目插图沿用原项目图集。 |

新制地砖及场景物件共用祭坛的受光方向。塔前营地、祭坛本体、血珠和标题插画沿用原版设计。旧楼层陈设保留在档案图集，新版塔内场景绘制以本节的建筑设施为准。[石材原图](../assets/edition/environment.png) · [建筑与书册画稿](../tools/art/paint_architecture.py)

### 十层原生像素建筑、塔顶与点光

各层新图绘制在其实际脚印上。`fixture_01`–`fixture_07`、`fixture_09`、`fixture_05_guard` 和 `fixture_10_pillar` 直接使用 `FloorTopology.STRUCTURE` 对应障碍的矩形和种子偏移。静态低位石件占其可见矩形，通用掩体只补没有专属画稿的障碍。浅接触阴影从脚印下缘延伸约九个世界单位。楼层的脚点和投影遮挡都由相同的布局矩形决定。新原画为本项目原创像素绘制，原生大小见下。 [绘制工具](../tools/art/paint_tower_fixtures.py) · [场景锚点](../scripts/arena.gd) · [通行布局](../data/floor_topology.gd)

| 位置 | 原生尺寸 | 图层及用途 |
| --- | --- | --- |
| F1 门廊 | 46 × 42、82 × 44 | `fixture_01` 是带铁轴槽的结构石脚。`threshold_01` 的中心为 (640, 168)，利用三行阶缘把地面接到北拱。 |
| F2 断墙路 | 30 × 132、24 × 118 | 两段纵墙共用 `fixture_02`。`drain_02` 是中心 (652, 300) 的贴地排水槽。 |
| F3 井道 | 210 × 32 | 两段抬高的实体石缘内嵌铁格、提拉环和残链。玩家能按既有布局从旁绕行。 |
| F4 驻防前哨 | 32 × 134 | 低砌体内向箭孔沿纵向布置，铁件压在右缘。 |
| F5 精锐驻地 | 153 × 32、148 × 32 | 两条守关矮墙分别接管原先两个结构矩形，右墙绘有绞盘座，左墙为金属止闸轨。 |
| F6 侵蚀门厅 | 139 × 33 | 封堵砌体上有旧铁箍、撬痕和破裂处的侵蚀沉积。 |
| F7 裂隙回廊 | 121 × 31 | 沉陷拱脚、补修铆固件和断裂刻入实体掩体画稿。 |
| F8 咒印厅 | 154 × 81 | 封缄槽与残缺嵌铜环落在中心 (640, 258)。暗色嵌纹是可通过的地面层，招式预警由战斗系统提供。 |
| F9 临顶阶 | 33 × 147 | 北侧长向闸轨带止门销，接管两段相同走向的结构。 |
| F10 领主之座 | 150 × 89、50 × 48 | 王印中心为 (640, 287)。两处独立柱脚覆盖原柱脚的物理面积。 |
| F10 水晶 | 70 × 33、61 × 76、61 × 76 | 石箍座和晶体使用受环境照明的底图，细纹与上升像素使用独立发光层。锚点为 `ArenaLayout.EXIT_POSITION`，晶体左上偏移 (-30, -68)。休眠、可触摸和激活共用底图。 |
| 终幕天际线 | 两张 640 × 360 | `summit_skyline` 是外部山谷、崖缘和塔的透明前景，`summit_clouds` 是独立的半透明阴云带。Skyline 与云层均为本项目绘制。 |
| 祭坛 | 两张 90 × 85 | `altar_stone` 和 `altar_runes` 来自原道具图集 (765, 73, 281, 264) 的可复现拆层。左右和底片位置保持原矩形。血珠显示尺寸 26 × 26、中心偏移 (0, -25)。 |

世界画布按 F1–F4、F5、F6–F9 和 F10 四组配置环境色。火焰中心取已有石灯的坐标再上移 27 像素。高画质按相机距离挑两盏火灯计算 PCF5 投影。低画质保留同一组点光和脚边阴影。血珠红光直径 138 像素，有珠时渐入，取珠后 0.34 秒淡出。HUD 独立于塔内画布，机关警示和拾取按键通过不受世界照明影响的材质绘制。 [光源、遮挡与优先规则](../scripts/tower_lighting.gd) · [祭坛](../scripts/altar_visual.gd) · [水晶](../scripts/summit_crystal.gd)

拾取图标由原件缩到最长边 26 像素，初次落地缓动 0.22 秒。淡影按武器长边、药材、卷册或装备脚点调整。焦点描边取实际像素不透明边缘，按键文本读取当前互动绑定。营地指示继续使用对应武器轮廓与小箭头。 [掉落贴图与焦点](../scripts/pickup.gd)

## 生成原画与使用来源

北墙原画、山谷远景、十室塔剖面于 2026-11-23 使用 OpenAI 内建 ImageGen 生成。北墙的材料参考板由项目既有 `actors.png`、`props.png`、`portraits.png` 和 `floor_scenery.png` 裁切拼接，祭坛位于 `props.png` 的 (765, 73, 281, 264) 区域。下列工作母图保留最终装配使用的像素。谷地工作母图为 640 × 360，拱道 384 × 256，塔身 397 × 992。精确遮挡轮廓、闸门、分段缩放、灯位及合成均由项目工具定义。[生成工作母图](../tools/art/sources/) · [合成工具](../tools/art/paint_architecture.py)

其余新增像素画与脚本由 Codex 为本项目制作。生成图及其衍生图依账户适用的 OpenAI 条款使用。项目原创建材与代码按仓库根目录许可证分发。保留项目既有第三方资源与字体的权属说明。[项目许可证](../LICENSE) · [原版素材来源](asset-handoff.md) · [OpenAI 使用条款](https://openai.com/policies/terms-of-use/)

### 山谷背景原始提示

> Use case: illustration-story. Asset type: full-bleed background illustration for a gothic pixel-art action RPG's vertical tower transit screen. An ancient, solitary, dark basalt tower in distant mountain fog at night. Compose as a panoramic landscape with the actual tower absent: a deep open valley in the central one-third of the frame, framed by fractured dark cliffs and bare pine silhouettes on the left and right. The game will place its own architectural cross-section in this broad empty center. An abandoned pilgrim camp with one tiny amber fire in the lower left, a few ancient ruins in the far right distance. Upper sky deep midnight Prussian blue with sparse stars and cloud bands, a sliver of warm dawn on the right horizon. Hand-pixelled 1990s dark-fantasy RPG scenic matte, sculpted stepped shapes, restrained clustered pixel highlights, rock strata, deliberate graphic silhouette, brass and patinated pewter, polished original game illustration, horizontal 16:9 composition. No typography, no tower, no characters in foreground, no logo, no border, no interface.

### 北墙拱梯原始提示

> Use case: stylized-concept. Make a single compact, large, transparent PNG game sprite: front-facing three-quarter OVERHEAD view of a north-facing, walk-in dungeon stairwell seamlessly built into a horizontal sliver of north wall. Short broad worn stone stairs running AWAY from viewer ascend from the bottom center INTO the shadow of the arch. Seven shallow irregular steps begin flush with two or three modest flagstones at bottom center. Squat broad semicircular arch above, two chunky flanking piers, broken stubs of wall left and right. Illustration style matches the existing altar reference: chunky irregular hewn ashy-grey slate blocks with subtly mauve shadows, warm desaturated tan highlights narrowly stroking chipped upper-left edges, dark outlines, grouped dithering, hand-painted dense 1990s RPG pixel art. Small stone grains and distinct planes, careful joint logic. Deep black arch interior WITH EMPTY OPEN PASSAGE around top four treads. Two very small amber torches inset in jambs. Compose approximately 3:2 wide, stairs pointing exactly toward bottom of image, frontal symmetry broken by different cracks in stones, foot of staircase visible bottom center. Keep arch apex clear. NO scenery background, NO standalone platform underneath, no detailed extended ground, no borders, no text, no symbols, no walking character, no red runes. Single isolated architectural sprite filling canvas, genuinely transparent exterior with crisp alpha. The existing altar in the reference is only a material/lighting reference; no altar in the output.

### 十室塔身原始提示

> Use case: illustration-story. Original premium dark fantasy pixel-art vertical tower cross section, isolated on transparent background, frontal orthographic 2D side elevation of an entire slender tower from pointed weathered copper roof to massive rock footing. Art-direction match: desaturated navy night shadows on weathered charcoal and mauve ashlar, harsh chips on upper-left stone edges, worn copper ridges, low warm amber room lights. Stack TEN separately visible inhabited rooms vertically INSIDE one architectural shell, one side-by-side architectural scene per story, evenly spaced horizontally running stone floor slabs, readable as a cut-away dollhouse, taller than wide (approximately 2.5:1 tall). Exterior buttresses, side turrets, bent iron pipes, corbels, dramatic uneven medieval roof, ancient lost-tech in a few rooms. Lower rooms contain casks, crumbled masonry, stairs and abandoned camp blankets; middle rooms have weapon racks, hanging banners and a furnace; upper rooms have encroaching purple-corruption roots and broken bell; top chamber a throne. Each room is a convincing deep space in shadow, furniture and atmospheric cast light. No black rectangular diagram borders or repeated identical arched-window grid, no text or numerals, no overlay or labels. Entire building centered, full body with margins, transparent around all exterior silhouette and exposed rocky foundation. Hand-painted 16-bit PC-98 pixel art with restrained clustered brushwork, appealing crisp silhouette and architectural detail. Preserve earthy texture near the foundation. Light from the upper left. No landscape backdrop, no sky. Standalone elevated original game asset.

## 重建与核对

在仓库根目录运行。本次核对使用 Python 3.12.14 与 Pillow 13.0.0。在独立临时目录运行以下两支 Python 工具后，39 张运行图与握点脚本均与交付版本逐字节一致。`tools/art/.gdignore` 将生产工具和三张工作母图排除在 Godot 资源导入之外，游戏只加载 `assets/upgrade/` 的成图和 `data/` 下的选帧、握点脚本。

```sh
python3 tools/art/paint_actors.py
python3 tools/art/paint_architecture.py
python3 tools/art/paint_tower_fixtures.py
godot --headless --path . --import
```

角色工具会同时写入 `assets/upgrade/actors/*.png` 与 `data/upgrade_grips.gd`。建筑工具写入 `assets/upgrade/props/*.png`。制作端已核对明暗闸门合成、正背侧方向、左右定姿、中段藤蔓房与顶层王座、全部图格透明边界，以及 39 张运行图的导入描述文件。实际包内的两档界面尺寸、遮挡、路线和镜头以候选版 QA 的截图、录像为准。
