-- [[ ExBoss Metadata ]]
-- 此文件由打包脚本自动生成或修改，用于控制版本号。
-- 请勿手动通过 Git 提交修改此文件中的版本号，除非你是为了测试。

ExBoss_MetaData = {
    version = "v26.8.28.2345",
    changelog = {
        version = "v26.8.28.0712",
        title = "v26.8.28.0712 更新日志",
        publishedAt = "2026-08-28 07:12",
        fontSize = 14,
        content = [[
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
