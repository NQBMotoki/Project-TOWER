# Project TOWER 音乐与声音制作

0.4.0-dev · 2026-11-25

游戏中的塔主题以 D–A–G–F 开头。塔前由竖琴引入，低层交给单簧管，F5 精锐驻地将它写成不对称的守关节拍，侵蚀区把它拆成断续的回应，领主战再把动机扩成铜管乐句。最后一击后，短乐句回到 D。靠近有血珠的祭坛时，石座用竖琴与钟琴回应。

## 乐谱、母带与循环点

八份标准 Type 1 MIDI 均为 4/4、D 小调、480 PPQ。可在 GarageBand 或其他支持标准 MIDI 的编曲软件中打开，按轨名更换音色并编辑音符。实际乐器采样与混响由离线渲染器制作。每组 FLAC 都从第一个采样开始对齐，格式为 44.1 kHz、24-bit、立体声。将同一组所有分轨以单位增益相加即可重建无损母带。[MIDI 乐谱](../audio_project/scores) · [无损分轨](../audio_project/stems) · [运行时音乐](../assets/audio/music)

| 曲目与触发 | BPM / 小节 | 有效采样帧 | 声部与播放方式 |
| --- | --- | ---: | --- |
| grounds · 标题、塔前 | 76 / 16 | 2,228,211 | 竖琴、偶尔出现的大提琴和长笛、钟琴。三路合成立体声循环。 |
| tower · F1–F4 | 96 / 16 | 1,764,000 | bed 低弦、theme 单簧管、pulse 拨弦与定音鼓、color 中提琴与圆号。四路 Ogg 同步循环。 |
| elite · F5 守关 | 108 / 16 | 1,568,001 | 3+3+2 重音、低铜管、金属回声。换式后提起铜管回答和定音鼓。四路 Ogg 同步循环。 |
| rift · F6–F9 | 84 / 16 | 2,016,001 | 低弦相邻半音、错开正拍的拨弦、玻璃泛音和断续簧管。后续楼层逐步提起高声部。四路 Ogg 同步循环。 |
| lord · F10 对话与战斗 | 114 / 16 | 1,485,474 | 铜管动机、弦群应答和低鼓。对话时减去攻击节奏，战斗阶段抬升铜管、第二弦部和鼓。四路 Ogg 同步循环。 |
| ending · 出口与胜利 | 70 / 16 | 2,419,200 | 长笛、中提琴、低弦和竖琴。三路合成立体声循环。 |
| cadence · 清场 | 96 / 2 | 220,500 | 单簧管、低弦、竖琴。5 秒收束，播放一次。 |
| altar · 靠近可收珠祭坛 | 76 / 2 | 278,526 | 竖琴、钟琴；石座位置播放一次，时长约 6.32 秒。 |

循环区间为从第 0 帧到表中帧数前一帧。按 MIDI 导拍量化到整数微秒后取总帧数。乐器释放和反射声折回曲头，两句一次性动机保留独立尾音。同区楼层和波次沿用同一个播放位置。跨区时在拍点附近收低旧曲，停止后启动下一曲的四路混音。F5 和 F10 的阶段差异从下一小节开始应用。清场对齐下一个拍点进入收束，读入已清场楼层后直接恢复环境声。进入祭坛 148 个世界单位内触发动机，离开至 210 单位外可重新触发，冷却 14 秒。[基础编曲](../tools/audio/compose.py) · [分区编曲与渲染](../tools/audio/regional_score.py) · [运行时混音](../scripts/sound_manager.gd)

## 拟音、环境与总线

- 87 个事件使用 262 个单声道 44.1 kHz、16-bit PCM 短音。新增敌人拟音将移动、预警、出手和触墙分开。史莱姆使用下坠和贴地拍击，哥布林使用较沉的脚步与皮革，骷髅法师和骷髅弓手分别使用骨节咏唱与细弦，幽灵的显形使用低频吸入。精锐使用骨甲与金属，领主的扫击、齐射、咒印与后段封路分别有独立起音。优先预警绕开房间混响，并压低配乐和普通拟音。相邻变体避开重复录音，单次塔顶长演出沿用固定时长的声轨。[事件与录音层明细](../audio_project/foley-sources.tsv) · [新拟音音层](../tools/audio/regional_foley.py)
- 紫能量入体、确认腐化和成功魔化分别用迅速下坠、短泛音与玻璃共鸣。触晶使用窄带起音和低频震动，外景天际变暗使用 3.51 秒下沉音，结尾留空间给结局配乐。触晶和 Boss 换式会短暂压低音乐。
- 箭板绷紧、发射、碰撞分别使用 `trap_warn`、`trap_arrow`、`arrow_impact`。绷紧声保留双击起音，短暂压低音乐、环境和普通拟音，绕过石室混响。预警从实际出箭口发声，碰撞声随弹道的首次接触点发声。[机关触发](../scripts/floor_features.gd) · [弹道命中](../scripts/projectile.gd)
- 塔前、F1–F3、F4–F5、F6–F9、F10 各有连续底声，循环依次为 36、38、35、40、37 秒。驻防层增加金属共鸣，侵蚀层增加低频，塔顶加宽声场并延长拟音混响。营地火塘和各层石灯使用 25 秒的单声道火声，北端通路使用 24 秒的单声道气流。局部声源按距离衰减，换层后旧声源在 0.28 秒内退出。间歇事件包含滴水、链响、裂隙和阵风。[环境循环](../assets/audio/ambience) · [剪辑与配方](../tools/audio/render_foley.py)
- Music 接收背景配乐与清场收束。Effects 接收 TowerFoley、TowerWarnings、TowerAmbience 和界面预听。有位置的祭坛回应走 TowerAmbience，因此关掉音乐仍能凭声音寻找祭坛。暂停时音乐降低 7 dB，环境降低 5 dB；Master 的限幅上限为 −1.2 dBFS。[音量与路由](../scripts/sound_manager.gd)

## 第三方录音与加工

| 作者与来源 | 许可 | 本作采用及加工 |
| --- | --- | --- |
| Versilian Studios，VSCO 2 Community Edition | CC0 1.0 | 基础乐谱以采样的原始根音移调，按力度、时值、声像和房间脉冲响应渲染。F5、侵蚀区和 F10 的制作从现有分轨提取了圆号与单簧管起音，其余声部由项目合成。[作者及许可](https://versilian-studios.com/vsco-community/) · [固定采样版本](https://github.com/sgossner/VSCO-2-CE/tree/440300901dfe9275fd84e0b7763af1f8443ae62e) · [逐曲清单](../audio_project/orchestra-sources.tsv) · [复用录音出处](../audio_project/instrument-sources.tsv) |
| Kenney，Impact Sounds 1.0、RPG Audio 1.0 | CC0 1.0 | 两包共取 92 个不同源文件。脚步、布料、木石、金属、玻璃、钱币和书本录音经裁切、滤波、变速和叠加。新录音层从已注明来源的游戏拟音再剪辑。表中 synthesis/ 项为项目离线合成的音层。[Impact Sounds](https://kenney.nl/assets/impact-sounds) · [RPG Audio](https://kenney.nl/assets/rpg-audio) · [固定录音镜像](https://github.com/GeorgeQLe/assets-sfx-combat/tree/9662dc1bed3b06ae753045915f9accfac044c7ce/assets/kenney) · [逐变体清单](../audio_project/foley-sources.tsv) |
| Félix Blume（felix.blume），Freesound #139337，火地岛草原风 | CC0 1.0 | 采用 AmbientSounds 中的 wind.ogg 节选，在 4、43、83、11、112、69 秒处为营地、井道、驻防、侵蚀、塔顶、楼梯取段。按原作者标注解码 M/S，再滤波、调宽、叠加区域色彩，以 3 秒等功率交叠收尾。[原作者与许可](https://freesound.org/people/felix.blume/sounds/139337/) · [实际取样版本](https://github.com/Muges/ambientsounds/tree/7ef9aefeeed93c37bca3cdb246a982dd1afce2f0) |
| inchadney，Freesound #132534，Fireplace.wav | CC0 1.0 | 取同版 AmbientSounds 的 fireplace.ogg 第 14 秒起共 28 秒，滤波、转单声道并交叠为 25 秒循环。[原作者与许可](https://freesound.org/people/inchadney/sounds/132534/) · [镜像署名](https://github.com/Muges/ambientsounds/blob/7ef9aefeeed93c37bca3cdb246a982dd1afce2f0/readme.md) |

原创作曲、编配、音层和混音工具采用仓库根目录的许可。第三方录音按各自的 CC0 声明使用。[项目许可](../LICENSE) · [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)

## 复现与验收

基础乐谱制作使用 Python 3.12、mido、NumPy、SciPy 和 SoundFile。只重建本次分区乐谱和新拟音时，使用 Python 3.12、NumPy、FFmpeg 和 libsndfile 即可。若系统无法自动找到 libsndfile，将 `TOWER_SNDFILE_LIBRARY` 设为库文件绝对路径。新 MIDI 的分轨名采用「声部/乐器」，保留固定导拍和 END 循环标记。直接调用渲染器会保留当前 MIDI。传入 `--compose` 会以工程内的编曲重建三份区域 MIDI。

```sh
python tools/audio/regional_score.py
python tools/audio/regional_foley.py
python tools/audio/check_assets.py
```

若同时需要重建旧乐谱、拟音或环境底声，检出上表三个固定版本，并以 VSCO 仓库、Kenney 镜像的 `assets/kenney` 和 AmbientSounds 仓库作为输入。Godot 导入 `assets/audio/` 的运行文件，制作分轨保存在 `audio_project/`。

```sh
python tools/audio/compose.py
python tools/audio/render_score.py "$VSCO_SAMPLES"
python tools/audio/render_foley.py "$KENNEY_SAMPLES" "$AMBIENT_SAMPLES"
python tools/audio/regional_score.py
python tools/audio/regional_foley.py
python tools/audio/check_assets.py
```

- FFmpeg 8.1.2 解码检查通过。26 路无损分轨与对应 Ogg 逐帧数对齐。262 个 WAV 的 PCM 指纹互异，最高样本峰值为 −1.11 dBFS。25 个运行时循环的首尾跳变均在各自相邻采样差值的第 99 百分位以内，最大为 0.00610 满幅。[重复执行检查](../tools/audio/check_assets.py)
- Godot 4.7.2 的分区播放检查在独立音频测试工程的源码与 Windows Desktop 预设导出的测试 PCK 各通过 67 项。四组四轨的时长、BPM 和循环一致。F1→F4 与 F6→F9 保留播放位置。F5 换式与 F10 第三阶段在下一小节调整分轨。45 个新增事件从打包内动态取到对应 WAV。精锐冲刺预警在预警总线采得峰值 −15.08 dBFS。该 PCK 检查通过同版 Godot 编辑器在 macOS 加载。
- 上轮 Godot 4.7.2 在 F3 的声场配置中触发战斗、预警、清场和祭坛事件，通过 AudioEffectCapture 逐总线采样。清场约十秒的窗口内，Music 的峰值为 −97.85 dBFS，环境峰值为 −20.03 dBFS。挥剑和箭板同时响起的窗口内，预警峰值为 −11.86 dBFS，普通拟音为 −13.66 dBFS，音乐为 −19.12 dBFS。上述窗口均采用三个音量滑块 100%。
- 关掉音乐并单独采集灯火，玩家分别站在灯左、右 65 单位时，朝向火源的一侧高出 1.33 dB；距离灯火 600 单位时输出为静音。主套件同时检查同步分轨、一次性动机、随机变体、PCM 导入与 Effects 的三路返回。[Godot 回归](../tests/test_mvp.gd)
- 总线数据来自引擎数字输出。耳机与实体扬声器的小音量清晰度、长时间重复疲劳及 Windows 声卡表现仍待真人试听。
