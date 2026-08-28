# EXBoss 配置导入 API

> 最后核对：2026-08-27  
> 状态：CURRENT（对应当前启用的 `Modules/Wago/API.lua`）

## 用途

`EXBossWagoAPI:ImportProfile` 是 EXBoss 唯一面向 Wago 与其他第三方插件的配置导入入口。调用方不得直接调用 `ExBoss.Voice.ImportExport`、`ExBoss.AppearanceProfiles` 或 `ExBoss.BossConfig`；这些都是 EXBoss 的内部实现链。

```lua
local ok, resultOrReason = EXBossWagoAPI:ImportProfile(D[profile])
if not ok then
    print("EXBoss configuration import failed: " .. tostring(resultOrReason))
end
```

`D[profile]` 必须是完整、未修改的导出字符串。不要去掉 `EXBXC:` 前缀、截断内容或手动修改其中字符。

## 方法

```lua
ok, resultOrReason = EXBossWagoAPI:ImportProfile(text)
```

| 参数 / 返回值 | 类型 | 说明 |
|---|---|---|
| `text` | `string` | EXBoss 导出的完整配置字符串。|
| `ok` | `boolean` | `true` 表示导入已接受；`false` 表示未完成导入。|
| `resultOrReason` | `table` / `string` | 成功时为结果表；失败时为可显示或记录的原因。|

调用必须发生在非战斗状态。战斗中会返回：

```text
cannot import configuration in combat
```

## 支持的字符串

### 当前 v7 综合包（推荐）

前缀：`EXBXC:`  
内部类型：`version = 7`、`payloadType = "exboss_bundle"`

这是 EXBoss 当前“导入/导出”页面生成的字符串。它可以包含：

- 一个外观配置；
- M+ 配置场景；
- 团本配置场景；
- 每个场景内的 `Author + User` 配对与职责映射（`assignments`）。

导入成功时，API 会：

1. 校验整个包；
2. 包名存在时，以包名为外观和 Author 配置加前缀；若接收方已有同名配置，则自动生成不重复的 `(... Imported)` 名称；
3. 导入并启用其中的外观配置（若包含）；
4. 对 M+ / 团本的每个场景，导入所有职责映射实际需要的 `Author + User` 配对；
5. 自动把包内 `assignments` 写入对应职责，因此默认切换至该包指定的配置；
6. 发布新的 Runtime，使当前 EXBoss 配置立即切换。

成功结果的形状为：

```lua
{
    appearance = true, -- 包内含外观且已导入并启用；否则为 false
    mplus = { imported = 1, assignments = 3 }, -- 或 nil（包中未含 M+）
    raid = { imported = 1, assignments = 3 },  -- 或 nil（包中未含团本）
    names = { appearance = "默认外观 (Imported)" }, -- 实际写入的名称
    reloadRequired = true, -- 本次导入切换了外观或职责时为 true
}
```

该 API 不会自行调用 `ReloadUI()`。通过 Wago Creator UI 导入时，Wago Creator 会在整批插件配置全部处理完毕后统一提示并执行重载；第三方自行直接调用时，成功结果中的 `reloadRequired = true` 表示调用方应在自己的导入批次结束后调用 `ReloadUI()`。

### 旧 v6 单配置包（兼容）

前缀同样是 `EXBXC:`。内部类型为：`version = 6`、`payloadType = "exboss_author_user_values"`。

此格式只含一个场景中的一个 `Author + User` 配对，**没有**职责映射。因此它仍可导入，但无法恢复“各职责应切换到哪份配置”，不会自动切换职责或重载界面。若 Author 名称已存在，API 同样会自动生成不重复的导入名称。

`EXBossWagoAPI:ExportProfile(key)` 目前生成的就是这种 v6 单配置字符串；保留它是为了兼容既有 Wago 流程。

## 失败与冲突

API 会拒绝无效、损坏、超过限制或不受支持的字符串。导入还可能因以下正常保护而失败：

- 依赖的 EXBoss 配置模块尚未可用；
- 在战斗中调用。

第三方插件应显示或记录返回的错误原因，不应通过改写字符串、直接写 SavedVariables 或调用内部导入函数绕过这些检查。

## 第三方集成示例

```lua
local preset = D[profile]
local ok, resultOrReason = EXBossWagoAPI:ImportProfile(preset)

if not ok then
    -- 在自己的界面中显示 resultOrReason。
    return
end

if resultOrReason.reloadRequired then
    ReloadUI()
end
```

源码：`EXBoss/Modules/Wago/API.lua`、`EXBoss/ExBossVoice/ImportExport.lua`、`EXBoss/Modules/Boss/Store.lua`、`EXBoss/Core/ExBoss_AppearanceProfiles.lua`。
