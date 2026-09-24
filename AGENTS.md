# 识曲 (ShiQu Music) — 项目协作约定

HarmonyOS 原生音乐播放器，ArkTS + ArkUI，Stage 模型，最低兼容 API 23（targetSdk API 24）。

## 自动推送约定（必须遵守）

**每次完成代码修改后，必须自动执行提交并推送，无需询问用户：**

```bash
git add -A
git commit -m "<中文提交信息，说明本次改动>"
git push
```

- 提交信息使用中文，第一行用 `feat:/fix:/rename:/docs:` 等前缀概括改动。
- `git add -A` 会把工作区所有变更（包括用户自己手动编辑的文件）一并提交，这是期望行为。
- 仅在用户明确说"先别推/暂缓提交"时才跳过推送。

## Git 环境说明

- 远程：`origin = https://github.com/wenmangdesu/shiqu-music.git`，主分支 `main`。
- 访问 github.com 需要走本机代理，已配置**仅对 github.com 生效**：
  `git config --global http.https://github.com.proxy http://127.0.0.1:33210`
  - 用户更换代理端口时，更新为 `http://127.0.0.1:<新端口>`。
  - 若推送报 `Failed to connect to 127.0.0.1`，说明代理软件未开，提示用户开启后再推；不要擅自改成全局代理。
- 凭据已由 Git Credential Manager 保管，推送不应弹出登录窗口。

## 工程要点（快速上手）

- 构建：DevEco Studio 打开工程根目录直接 Run；命令行构建见 README。
- 在线曲库：`entry/src/main/ets/common/Constants.ets` 中 `JAMENDO_CLIENT_ID`（真实曲库）、`ONLINE_API_BASE`（自建 API 契约）。
- 本地导入采用 DocumentViewPicker（免权限），元数据解析器在 `utils/MetaParser.ets`。
- 深浅色资源在 `resources/base` 与 `resources/dark` 的 `element/color.json` 成对维护，新增颜色两处都要加。
- UI 文案一律中文；关键逻辑加中文注释。
