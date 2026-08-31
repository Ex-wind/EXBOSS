-- [[ ExBoss Metadata ]]
-- 此文件由打包脚本自动生成或修改，用于控制版本号。
-- 请勿手动通过 Git 提交修改此文件中的版本号，除非你是为了测试。

ExBoss_MetaData = {
    version = "v26.8.31.1641",
    changelog = {
        version = "v26.8.31.1641",
        title = "v26.8.31.1641 更新日志",
        publishedAt = "2026-08-31 16:41",
        fontSize = 14,
        content = [[
@H1@ v26.8.31.1641

@CN@ @H2@ 状态系统
@CN@ - 我们注意到了某些插件会在某些场景下出现一些问题 导致客户端会在极短时间内收到3-4千条事件
@CN@ (然后导致我们这些依赖正常低频事件刷新的插件卡顿 背锅) 我们目前已经加上事件节流来解决这个问题
@CN@ - 补充地图判定刷新事件 这解决了部份小怪CD错误的问题

@CN@ @H2@ 错误修复
@CN@ - 修复了使用Criteria获取副本首领进度时 因为非zhCN客户端导致的小怪判定错误
@CN@ (这是一个很早期的偷懒硬编码 修复后会解决一些怪物判定的问题)

@CN@ @H2@ 说明
@CN@ - 小怪内置CD因为12.0暴雪的限制 我们是采用推理的方式去锁定怪物 推理分为两个层面
@CN@ - L1的意思是 在第一层就能够锁定 : 第一层通常是各种静态资料 如地图位置等等
@CN@ (通常意味着你开怪瞬间就能看到技能CD情况)
@CN@ - L2的意思是 在L1过滤后 如果候选还存在2只以上的怪物 则会根据怪物的施法特征进行推理
@CN@ (通常意味着你开怪后看不到技能CD/又或者是错误的技能CD 但是在第一次施法时能够正确的校准并且正确的提醒)
@CN@ - 语音和技能CD是两种不同的调度 语音需要在施法瞬间播放 因此能推理的条件有限
@CN@ - 技能CD则是可以在怪物读条完后收集特征再推里 所以准确度较高
@CN@ - 本赛季暴雪不修改的情况下 我们能慢慢调试恢复到90%以上的准确率

@CN@ @H2@ %i:1762
@CN@ - 重做了1号BOSS后的4波怪物 现在能够在推理L1直接被锁定(如果不额外拉取别的怪物情况下)
@CN@ - 修复了整个副本大多怪物的判定问题
@CN@ - 修复了%n:138489技能不提示的问题 (新增了这只怪物的技能语音/配置作者需要补充修改)

@CN@ @H2@ %i:2923
@CN@ - 重做了大多数的小怪 并解决了大多数问题
@CN@ - 1/2号BOSS后面的小怪 仍然需要在读条开始时才能锁定视别(或是预先推理 然后读条开始时校准)

@CN@ @H2@ 开发计划
@CN@ - 我们会在今天会做一次性能审查和优化

@EN@ ## State System
@EN@ - We identified an issue where certain addons can, in some situations, cause the client to receive 3,000–4,000 events within a very short period of time.
@EN@ This can cause addons like ours, which rely on normal low-frequency event updates, to lag and take the blame. We have now added event throttling to address this.
@EN@ - Added map-detection refresh events. This resolves some incorrect trash cooldown detections.

@EN@ ## Bug Fixes
@EN@ - Fixed incorrect trash identification caused by non-zhCN clients when using Criteria to obtain dungeon boss progress.
@EN@ This was an early hardcoded shortcut; fixing it resolves several trash-identification issues.

@EN@ ## Notes
@EN@ - Due to Blizzard's 12.0 restrictions, built-in trash cooldowns identify mobs through inference. This inference has two layers.
@EN@ - L1 means a mob can be identified in the first layer. This layer usually uses static information, such as map location.
@EN@ This normally means you can see skill cooldowns as soon as combat starts.
@EN@ - L2 means that, after L1 filtering, two or more candidates still remain. The addon then identifies the mob through its casting characteristics.
@EN@ This normally means you may not see skill cooldowns, or may see incorrect cooldowns, when combat starts. However, the addon can calibrate correctly on the first cast and provide accurate alerts afterward.
@EN@ - Voice alerts and skill cooldowns use two separate scheduling systems. Voice alerts must play at the moment a cast begins, so the available inference conditions are limited.
@EN@ - Skill cooldowns can collect features after a cast finishes before making an inference, so their accuracy is generally higher.
@EN@ - As long as Blizzard does not make further changes this season, we can gradually test and restore accuracy to above 90%.

@EN@ ## %i:1762
@EN@ - Reworked the four trash waves after the first boss. They can now be identified directly at L1, provided no additional mobs are pulled.
@EN@ - Fixed identification issues for most trash mobs in the dungeon.
@EN@ - Fixed %n:138489 skills not being announced. Added this mob's skill voice/configuration data; configuration authors will need to update their setups.

@EN@ ## %i:2923
@EN@ - Reworked most trash mobs and resolved most issues.
@EN@ - Trash after the first and second bosses still needs to be identified when casting begins, or inferred in advance and calibrated when casting starts.

@EN@ ## Development Plan
@EN@ - We will conduct a performance review and optimization pass today.

@H1@ v26.8.29.2102

@CN@ @H2@ 通用
@CN@ - 修复了一些会导致报错的问题

@CN@ @H2@ 所有小怪和BOSS
@CN@ - 因为暴雪在近期又改了一些小怪的身份 所以导致一些功能原本好的又失效
@CN@ - 我们当前已经收集完所有小怪的相关问题

@CN@ - "所有问题都会在这周末修复完"

@CN@ - (因为暴雪的限制 不可能做到100% 但是至少周末后能修复到90%以上)
@CN@ - 剩余10%我们会在之后做针对性的处里(如果技术上能做到的话)

@CN@ @H2@ 关于BOSS
@CN@ - 所有的BOSS额外提示我们也会在周末完成 由于时间关系暂时无法给所有设置都有自定义选项

@EN@ @H2@ General
@EN@ - Fixed several issues that could cause errors.

@EN@ @H2@ All Trash Mobs and Bosses
@EN@ - Blizzard recently changed the identities/IDs of some trash mobs again, which caused some previously working features to stop functioning.
@EN@ - We have now finished collecting all known issues related to trash mobs.

@EN@ - "All of these issues will be fixed by the end of this weekend."

@EN@ - Due to Blizzard's restrictions, it is impossible to achieve 100% functionality, but we expect to have at least 90% of these issues fixed by the end of the weekend.
@EN@ - We will address the remaining 10% individually afterward, where technically possible.

@EN@ @H2@ About Bosses
@EN@ - We will also finish adding all additional boss alerts by the end of the weekend.
@EN@ - Due to time constraints, we are currently unable to provide customizable options for every setting.

@H1@ v26.8.28.0712

@CN@ @H2@ 通用
@CN@ - 临时修复 %i:1762 的一些小怪问题
@CN@ - 仍然有一些小怪没修复 我们会在这两天陆续修复
@CN@ - 怪物数量的预锁定现在会在5秒缓存后释放
@CN@ - 删除了所有依赖仇恨事件的逻辑 现在依赖怪物战斗的State Transition来做CallBack

@CN@ @H2@ 公告
@CN@ - 我们注意到了暴雪对一些怪物的判断逻辑进行了改动修复 我们正在针对这些怪物的推理逻辑重做中 预计24小时内修复完成

@CN@ @H2@ WAGO
@CN@ - 升级了导入API到V7 如果你是配置分享作者
@CN@ 该使用新的EXBossWagoAPI:ImportProfile()来导入配置 (建议重新生成字符串)

@EN@ @H2@ General
@EN@ - Temporarily fixed issues affecting some trash mobs in %i:1762. More mobs still need fixes and will be addressed over the next two days.
@EN@ - Trash-mob count pre-reservations are now released after the 5-second cache expires.
@EN@ - Removed all threat-event-based logic. Runtime updates now rely on trash combat State Transition callbacks.

@EN@ @H2@ Announcement
@EN@ - We have noticed that Blizzard changed the identification behavior for certain mobs. We are rebuilding the inference logic for those trash and expect to complete the fixes within 24 hours.

@EN@ @H2@ WAGO
@EN@ - Updated the import API to V7. If you are a profile-sharing author, use the new EXBossWagoAPI:ImportProfile() to import profiles. Regenerating your export strings is recommended.

@H1@ v26.8.25.0013

@CN@ @H2@ 通用

@CN@ - 新的更新日志系统上线 以后每次更新都会主动告知更新内容和后续修复/开发计划

@CN@ @H2@ 通用设置
@CN@ - 加入了一键关闭团本提示勾选框
@CN@ - 加入了施法进度条的开关

@CN@ @H2@ 施法进度条
@CN@ - 修复了一些施法进度条不显示的问题(大多都在BOSS)
@CN@ - 如果还有遇到任何施法进度条不显示的地方请回报给我 谢谢!

@CN@ @H2@ 中央5秒倒数
@CN@ - 重做了整套系统 现在可以完全正常显示 如果你当前设置导致图标/时间偏移比较多
@CN@ 可以在设置页面的预览面板直接用鼠标拖动到正确位置

@CN@ @H2@ %i:2825
@CN@ - 修复了 %s:1252825 不显示的问题 现在会正确显示冷却时间和持续时间

@EN@ @H2@ General

@EN@ - The new changelog system is now live. From now on, every update will automatically notify you of what has changed and what fixes or features are planned next.

@EN@ @H2@ General Settings
@EN@ - Added a checkbox to disable all raid alerts with one click.
@EN@ - Added a toggle for cast bars.

@EN@ @H2@ Cast Bars
@EN@ - Fixed several issues where cast bars failed to appear, mostly during boss encounters.
@EN@ - If you still encounter any missing cast bars, please report them to me. Thank you!

@EN@ @H2@ Central 5-Second Countdown
@EN@ - Reworked the entire system, which should now display correctly. If your current settings cause the icon or timer text to be significantly offset,
@EN@ you can drag them directly to the correct position in the preview panel on the settings page.

@EN@ @H2@ %i:2825
@EN@ - Fixed an issue where %s:1252825 was not displayed. Its cooldown and duration will now appear correctly.

@H1@ v26.8.23.1113

@CN@ @H2@ 测试
@CN@ - 这是一个测试内容

@EN@ @H2@ TEST
@EN@ - TEST UPDATE
        ]],
    },
}
