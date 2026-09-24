# 云悦音乐 (Cloud Joy Music)

一款使用 **ArkTS + ArkUI（声明式范式）** 开发的鸿蒙原生音乐播放器，基于 **Stage 模型**，最低兼容 **API 23**（工程 targetSdk 为 API 24 / HarmonyOS 6.1.1）。

支持：本地音乐导入、在线搜索与多音质下载、完整播放控制、逐行/逐字歌词、桌面歌词、歌单管理、收藏、最近播放、后台播放 + 锁屏控制、深浅色自适应、主题色跟随封面等。

---

## 一、运行方法

1. 使用 **DevEco Studio** 打开工程根目录 `Harmonymusic`。
2. 确认 `build-profile.json5` 中 `compatibleSdkVersion` 为 `6.1.0(23)`、`targetSdkVersion` 为 `6.1.1(24)`（若本机 SDK 列表中没有 6.1.0，可在 File → Settings → SDK 安装对应版本，或把 compatibleSdkVersion 改回 `6.1.1(24)`）。
3. 选择 **Auto Signature** 自动签名（File → Project Structure → Signing Configs 勾选）。
4. 连接真机或启动模拟器，点击 **Run 'entry'**。
5. 首次启动会请求"通知"授权（用于播放通知栏），允许后体验更完整。

> 在线搜索/下载在未配置真实 API 时自动使用**内置演示音源**（公开示例曲目，可直接播放/下载，用于验证完整链路）。

## 二、项目结构（MVC/MVVM 分层）

```
entry/src/main/ets/
├── common/
│   └── Constants.ets            # 全局常量、AppStorage键名、接口定义(IPlayerHooks/IPlayerListener)
├── model/                        # 数据实体层（对应RDB表结构）
│   ├── Song.ets                  #   歌曲：id/title/artist/album/duration/filePath/coverUrl/fileSize/bitrate/format/source/lyricsPath/isLiked/playCount/addedTime
│   ├── Playlist.ets              #   歌单：id/name/coverPath/songIds/createTime/updateTime（id=-1为虚拟"我喜欢"）
│   ├── DownloadTask.ets          #   下载任务：id/songId/url/filePath/progress/status/speed/quality...
│   └── PlayHistory.ets           #   播放历史：songId/playTime
├── utils/                        # 工具层
│   ├── Logger.ets                #   hilog统一日志
│   ├── FmtUtil.ets               #   时长/大小/速度格式化、文件名清洗
│   ├── LrcParser.ets             #   LRC歌词解析（逐行 + 增强逐字卡拉OK）
│   ├── MetaParser.ets            #   音频元数据解析（ID3v2/FLAC/WAV/M4A：标题/歌手/专辑/时长/封面提取）
│   └── ColorUtil.ets             #   封面主色提取（主题色跟随封面）
├── service/                      # 业务服务层
│   ├── PrefsService.ets          #   @ohos.data.preferences 偏好持久化
│   ├── DbService.ets             #   @ohos.data.relationalStore 结构化存储（songs/playlists/download_tasks/play_history）
│   ├── LibraryService.ets        #   本地音乐库：沙箱扫描 + DocumentViewPicker导入 + 元数据入库
│   ├── OnlineService.ets         #   @ohos.net.http 在线搜索（含演示数据回退）
│   ├── LyricsService.ets         #   歌词获取：本地.lrc → 缓存 → 在线接口 → 内置演示歌词
│   ├── DownloadService.ets       #   request.agent 下载队列（并发≤3、暂停/继续/取消、完成后自动入库）
│   ├── AvSessionHelper.ets       #   @kit.AVSessionKit 媒体会话（锁屏/控制中心）
│   └── PlayerService.ets         #   @ohos.multimedia.media AVPlayer封装 + backgroundTaskManager长时任务 + notificationManager通知
├── viewmodel/
│   └── AppModel.ets              # 全局ViewModel：状态聚合、业务编排、导航栈、播放联动
├── view/                         # 通用UI组件
│   ├── CoverImage.ets            #   封面（本地/网络/占位渐变）
│   ├── SongRow.ets               #   歌曲行（播放/序号/多选三种形态）
│   ├── MiniPlayerBar.ets         #   底部迷你播放条（常驻）
│   ├── LyricView.ets             #   歌词视图（自动滚动/高亮/逐字渲染/点击跳转）
│   ├── FloatLyrics.ets           #   桌面歌词悬浮层（可拖拽）
│   └── dialogs/
│       ├── InputDialog.ets       #   文本输入对话框
│       ├── QualityDialog.ets     #   下载音质选择（128K/320K/FLAC）
│       └── PlaylistPickerDialog.ets # 添加到歌单选择
├── pages/                        # UI层
│   ├── SplashPage.ets            #   启动页（Logo+版本）
│   ├── Index.ets                 #   主框架：Navigation路由 + 首页 + 迷你播放条 + 桌面歌词悬浮层
│   ├── home/
│   │   ├── HomePage.ets          #   四Tab容器（我的音乐/在线音乐/播放列表/我的）
│   │   ├── LocalTab.ets          #   本地音乐（排序/筛选/多选批量/菜单/导入）
│   │   ├── OnlineTab.ets         #   在线搜索/播放/下载
│   │   ├── PlaylistTab.ets       #   歌单管理（新建/重命名/删除/封面）
│   │   └── MineTab.ets           #   我的（统计/入口/最近播放）
│   ├── SearchPage.ets            #   搜索页（本地/在线双模式 + 搜索历史/热门）
│   ├── PlayerPage.ets            #   播放页（封面/侧滑切歌/进度/模式/收藏/倍速/队列/均衡器/音量手势/下载）
│   ├── LyricsPage.ets            #   歌词页（独立全屏）
│   ├── PlaylistDetailPage.ets    #   歌单详情（播放全部/添加/左滑移除/编辑）
│   ├── AddToPlaylistPage.ets     #   添加到歌单
│   ├── CreatePlaylistPage.ets    #   新建/重命名歌单
│   ├── PickSongsPage.ets         #   选歌加入歌单（多选）
│   ├── DownloadPage.ets          #   下载管理（队列/进度/暂停继续/删除）
│   └── SettingsPage.ets          #   设置（主题/音质/并发/缓存/关于）
└── entryability/
    └── EntryAbility.ets          # Stage模型入口（初始化编排 + 加载启动页）
```

## 三、技术要点说明

### 已使用的系统能力（对应要求）
| 要求 | 实现 |
|---|---|
| AVPlayer 播放 | `@kit.MediaKit` media.createAVPlayer；本地 fdSrc / 网络 url 双源；seek、倍速、播放模式 |
| 文件操作 | `@kit.CoreFileKit` fs：扫描/复制/删除/读写 |
| 媒体库元数据 | `@kit.MediaLibraryKit` photoAccessHelper.PhotoViewPicker 选曲/选封面（免权限）+ 自研 MetaParser 解析 ID3v2/FLAC/WAV/M4A |
| 网络请求 | `@kit.NetworkKit` http：搜索/歌词/封面下载 |
| 偏好持久化 | `@ohos.data.preferences`（getPreferencesSync） |
| 结构化存储 | `@ohos.data.relationalStore`：songs / playlists / download_tasks / play_history 四表 |
| 后台播放 | `@kit.BackgroundTaskKit` backgroundTaskManager 长时任务 AUDIO_PLAYBACK + KEEP_BACKGROUND_RUNNING 权限 |
| 通知栏/锁屏 | `@kit.NotificationKit` 通知 + `@kit.AVSessionKit` 媒体会话（锁屏/控制中心播放控制） |
| 下载 | `@ohos.request` request.agent 后台下载代理（队列、并发≤3、pause/resume/stop/delete） |

### 关于 API 12+ 与权限模型的说明
- HarmonyOS NEXT 对第三方应用**不开放整盘媒体扫描权限**（READ_IMAGEVIDEO 属受限ACL权限）。因此"本地导入"采用合规方案：
  1. 自动扫描应用沙箱目录（`files/download`、`files/imported`、`files/music`）；
  2. 通过 **DocumentViewPicker** 手动选择音频文件（无需任何敏感权限），复制进沙箱后解析入库；
  3. 播放时 AVPlayer 自动上报真实时长并回填数据库。
- "@ohos.media.library" 旧模块在 API 12+ 已由 MediaLibraryKit（photoAccessHelper）取代，本工程使用其选择器能力获取音频与封面。

### 设计上的取舍（已知边界）
- **音效均衡器**：UI/预设/自定义频段均已实现并持久化；但 HarmonyOS 公开 SDK 未向三方应用开放 EQ 频段 DSP 接口，实际音效依赖系统音频能力。
- **桌面歌词**：跨应用悬浮窗需要系统级 `SYSTEM_FLOAT_WINDOW` 权限，本工程实现为**应用内可拖拽悬浮层**（覆盖首页与各页面）。
- **在线音源**：默认启用 **Jamendo 真实曲库**（`Constants.JAMENDO_CLIENT_ID` 已配置，CC授权音乐、欧美曲库为主，可真实播放/下载，单音质三档同源）；歌词自动通过 **LRCLIB**（lrclib.net）匹配 LRC。把 client_id 置空则回退"自建API → 演示数据"链路。自建服务端按以下契约返回即可，客户端零改动：

```json
// GET {ONLINE_API_BASE}/search?keyword=xxx
{ "data": [ { "id":1, "title":"歌名", "artist":"歌手", "album":"专辑",
  "duration":240000, "url":"https://.../a.mp3", "cover":"https://.../c.jpg",
  "standardUrl":"...", "highUrl":"...", "losslessUrl":"..." } ] }

// GET {ONLINE_API_BASE}/lyrics?title=xx&artist=xx
{ "lyrics": "[00:00.00]..." }
```

### 数据存储位置
- 数据库/偏好：应用沙箱（`cloudmusic.db`、`cloudmusic_prefs`）
- 下载音乐：`files/download/`（request.agent 先落临时目录 cache/download，完成后自动转存持久目录）
- 手动导入：`files/imported/`
- 封面/歌词缓存：`cache/covers/`、`cache/lyrics/`

## 四、功能清单速查

- **启动页**：Logo + 版本，等待初始化完成后自动进入主页
- **首页**：搜索栏 + 四 Tab + 底部常驻迷你播放条
- **本地音乐**：自动扫描、手动导入、标题/歌手/专辑/时长排序、格式筛选、多选批量加入歌单、歌曲菜单（下一首播放/收藏/添加/移除）
- **在线音乐**：关键词搜索（歌曲/歌手/专辑）、在线播放、三档音质下载、下载完成自动入本地库
- **播放页**：播放/暂停/上一首/下一首/进度拖拽/倍速(0.75-2.0)/播放模式(单曲循环/列表循环/随机)/收藏/下载、**封面左右侧滑切歌**、点击封面切换歌词视图、右缘上下滑动手势调音量、播放队列（跳转/上下移动排序/删除）
- **歌词**：LRC逐行 + 增强逐字（卡拉OK渲染）、自动滚动、当前行高亮、点击行跳转播放位置、在线/本地/内置歌词多级获取、独立歌词页 + 应用内桌面歌词
- **歌单**：我喜欢（默认，收藏自动汇总）+ 自定义歌单（新建/重命名/删除/相册封面）、歌单内添加/左滑移除、播放全部
- **下载管理**：队列进度条与实时速度、暂停/继续/取消/重试、删除记录/删除文件、并发数可调（1-3）
- **设置**：深浅色（跟随系统/浅色/深色）、主题色跟随封面（自动取色）或固定主题色、默认播放模式/下载音质、并发数、缓存清理、历史清理、重新扫描、关于
- **其他**：最近播放记录（自动去重、保留200条）、深浅色全适配（自建 color 资源 + 系统跟随）、平板/折叠屏大屏约束（内容限宽居中）

## 五、常见问题

1. **装不上/报签名错误**：确认已配置自动签名；`KEEP_BACKGROUND_RUNNING`、`INTERNET` 均为 normal 级权限，无需 ACL。
2. **compatibleSdkVersion 报不存在**：把 `build-profile.json5` 的 `compatibleSdkVersion` 改为 `6.1.1(24)`，或在 SDK 管理器安装 6.1.0。
3. **搜索不到数据**：已默认启用 Jamendo 真实曲库（欧美为主），中文关键词可能无结果；换成 `piano`、`summer`、`rock` 等英文关键词体验最佳。停用 Jamendo 或接入自建 API 均在 `common/Constants.ets` 修改。
4. **本地歌曲时长显示 00:00**：部分格式（如无标签的 AAC/OGG）首次播放时由 AVPlayer 上报真实时长并自动回填。
5. **模拟器无法播放演示音源**：请确认模拟器/真机可访问外网（演示音源为 https 公开地址）。
