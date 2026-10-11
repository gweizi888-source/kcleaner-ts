# KCleanerTS

基于 [Keychain-Dumper](https://github.com/ptoomey3/Keychain-Dumper) 改造，面向 **TrollStore**、**iOS 15 / 16** 的钥匙串管理 CLI（开源）。参考 [KCleaner (kcc)](https://github.com/tansnote/kcc) 的常见能力做了扩展，**当前版本是命令行 + tipa 壳**，完整 GUI 后续可加。

## 不用 Mac 编译：GitHub Actions

推送代码到本仓库后，Actions 会在云端 macOS 上自动编译并上传 **`.tipa`**：

1. 打开仓库 **Actions** → 最新成功的 **Build KCleanerTS tipa**
2. 页面底部 **Artifacts** → 下载 `KCleanerTS-tipa`（解压得到 `KCleanerTS.tipa`）
3. 用 TrollStore 安装

也可在 Actions 里点 **Run workflow** 手动触发。

仓库地址：[github.com/gweizi888-source/kcleaner-ts](https://github.com/gweizi888-source/kcleaner-ts)

装好后若钥匙串权限不全，在设备上执行 `kcleaner_ts -T > ent.plist`，用 ldid 按 plist 重新签名，或把 `-T` 输出的 group 合并进 entitlement 后再打包。

## 功能（相对原版）

| 能力 | 命令 |
|------|------|
| 列出 access group 及条目数 | `kcleaner_ts -L` |
| 关键词过滤查看 | `kcleaner_ts -f 关键词` |
| 按 group 过滤 | `kcleaner_ts -G com.example` |
| JSON 导出（逐行） | `kcleaner_ts -j` |
| 按关键词删除（Generic + Internet） | `kcleaner_ts -F 关键词` |
| 清空 Generic + Internet | `KCCLEANER_CONFIRM=DELETE_ALL kcleaner_ts -X` |
| 生成 TrollStore 用 entitlement 模板 | `kcleaner_ts -T > ent.plist` |
| 原版能力 | `-e` `-g` `-n` `-a` `-s` 等 |

删除走 **Security.framework / SecItemDelete**，不直接改 `keychain-2.db` 文件，更适合 TrollStore 高权限 App。

## 环境

- **编译**：需要 **macOS** + Xcode 命令行工具，或 Theos + iPhoneOS 15+ SDK  
- **安装**：TrollStore 1.3+，iOS 15.0–16.x（与设备 TrollStore 支持范围一致）  
- **运行**：安装 tipa 后，用 **NewTerm / SSH** 执行 `kcleaner_ts`（当前无图形界面）

> 你在 Windows 上只能改源码；**真机编译必须在 Mac 上完成**。

## 快速编译（Xcode SDK）

```bash
cd kcleaner-ts
make
make trollsign    # 需已安装 ldid；或 make codesign + 开发者证书
./trollstore/pack-tipa.sh
```

将 `build/KCleanerTS.tipa` 用 TrollStore 安装。

## Entitlement 说明

1. 先用带 `*` 或最小权限的 plist 装一版，在设备上执行：  
   `kcleaner_ts -T > /var/mobile/Documents/kc-ent.plist`
2. 若条目不全，把 plist 里 **keychain-access-groups** 精简后重新 `ldid -S` 签名（组太多有时反而 dump 不到，与 Keychain-Dumper 文档一致）。
3. 若开启了 **iCloud 钥匙串**，清理本地后可能被云同步拉回，需先在系统设置关闭。

## Theos（可选）

```bash
cd theos
make
```

## 与 KCleaner 的差距（v0.1）

- 无按 App 图标列表、无 IDFA/OTA/NVRAM 等系统项  
- 无导入/导出 plist 备份包（仅有 `-j` JSON 行）  
- 无 SwiftUI 界面  

需要 GUI 时可在本仓库加 `ui/` 目标，复用 `kcleaner_ext.m` 里的逻辑。

## 许可

沿用 Keychain-Dumper 原始 BSD 条款；新增文件同项目维护。
