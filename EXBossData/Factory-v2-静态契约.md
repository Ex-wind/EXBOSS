# Factory v2 静态契约

唯一 M+ Factory 的非战斗事实真源是
`EXBOSSPY/1.Boss/config_factory_s12_s2.json`。它定义 Factory 身份、赛季、显式
8 个 Boss mapID、覆盖统计、静态来源、Trash 设置/单技能模板，以及副本/Boss 选项。
它也拥有 Boss 默认解析规则（事件类型配色、Pack 标签、默认 trigger 模板）、Boss
事件排除表，以及 Trash 的完整副本名单；Python 和 Lua 不得各自维护这些季节常量。

战斗事实不复制进 Factory：Boss 事件仍来自 `EncounterData.lua`；138 条小怪的
逐技能预设仍单份来自 `TrashCDPreset.lua`。`FactoryResolver.lua` 只在运行时将该
预设合并到 Factory 的 `spellEntryDefaults`，得到临时 `spellEntries` 基线，供
Author/User DIFF 使用。

生成和运行期均拒绝不完整的数据：实际覆盖范围完全由 Factory metadata 的
`season` 与 `coverage` 决定；Boss/Trash 静态源必须逐项匹配该 metadata。Factory
不包含事件或逐技能预设复制，也不包含职责分支。

## 静态事实绑定

Python 会以稳定 canonical JSON 分别计算 Factory 范围内 Boss 事实和 Trash preset
事实的 SHA-256。三个生成物携带同一契约：`EncounterData.lua` 暴露 Boss 指纹，
`TrashCDPreset.lua` 暴露 Trash 指纹，`Factory.lua` 写入 `sourceContract`（两指纹及
组合 `bindingSha256`）。不把事实大表复制进 Factory。

`revision` 保留人类发布版本；`effectiveRevision` 固定为
`revision@bindingSha256前16位`。Author、User、Entity 与导入协议绑定的是
`effectiveRevision`，因此任一事实变化即使忘记手改 release revision，也不能把旧
DIFF 静默套到新事实。

`FactoryResolver` 在取得基线、验证候选 Factory、导入及恢复已保存 Factory 前都会
比对本机两个事实契约。任一指纹不一致时 fail-closed：不解析、不激活、不导入。导入
失败不触碰当前 Factory/Author/User；重载发现旧导入 Factory 不匹配时，完整旧
`mplus` 树会移入 `EXBossDataDB.configV2.quarantinedMplus`，再启用本机验证通过的
Factory，绝不由该错配自动清空用户 DIFF。

Schema-2 当前只存在 M+ Factory、M+ Author 与 M+ User Entity。不存在 Raid 或
general 的冻结预设链、Loader、SavedVariables 根或兼容入口。

生成前验证（不写文件）：

```powershell
python "C:\Users\exw08\Desktop\EXBOSSPY\1.Boss\3.将EXCEL写入EncounterData.lua.py" --factory --dry-run
```

完整发布顺序是先生成 `EncounterData.lua`、`TrashCDPreset.lua`，再生成
`Factory.lua`；CI/本机还应运行 `EXBoss/tests/factory_static_fact_contract_test.py`。
