# 识曲 (ShiQu Music)

> 不识字，但识曲。

基于 **HarmonyOS NEXT + ArkTS + ArkUI（声明式范式）** 开发的原生音乐播放器，采用 Stage 模型，最低兼容 **API 23**（targetSdk 6.1.1(24)）。支持本地音乐管理、在线搜索与多音质下载、完整播放控制、逐行/逐字歌词、歌单、后台播放与锁屏控制，整体 UI 为笔记本涂鸦风格。

## 功能特性

**播放核心**
- 播放 / 暂停 / 继续 / 停止 / 上一首 / 下一首 / 自动切歌
- 四种播放模式：单曲循环、列表循环、随机播放、顺序播放
- 进度条拖拽；长按 ⏮/⏭ 快退/快进 15 秒
- 倍速播放：0.75 / 1.0 / 1.25 / 1.75 / 2.0
- 系统媒体音量调节、静音开关、播放页右缘滑动手势调音量
- 音效均衡器面板：流行 / 摇滚 / 古典 / 爵士预设 + 五段自定义（设置持久化）
- 定时关闭：15 / 30 / 45 / 60 / 90 分钟或播完当前歌曲即停
- 耳机 / 蓝牙音频设备断开自动暂停
- 续播记忆：重启应用自动恢复上次队列与播放进度（暂停态等待续播）

**本地音乐**
- 沙箱目录自动扫描 + DocumentViewPicker 手动导入（免存储权限）
- 音频元数据解析（自研）：ID3v2 / FLAC / WAV / M4A 的标题、歌手、专辑、时长与内嵌封面
- 支持 mp3 / flac / wav / aac / ogg / m4a
- 歌曲 / 歌手 / 专辑三种浏览模式，标题/歌手/专辑/时长排序，格式筛选
- 随机漫游：全库洗牌播放
- 多选批量加入歌单、歌曲菜单（下一首播放 / 收藏 / 加歌单 / 查看歌手专辑 / 分享 / 移除）

**在线音乐**
- 关键词搜索（Jamendo CC 授权曲库，支持配置自建后端）
- 在线流式播放、下载完成自动入本地库
- 歌词获取链路：本地 .lrc → 缓存 → LRCLIB 公开歌词库 → 内置演示歌词

**下载管理**
- request.agent 后台下载队列，并发数 1–3 可调，仅 Wi-Fi 下载开关
- 实时进度与速度、暂停 / 继续 / 取消 / 重试、三档音质选择
- 下载完成后自动解析元数据入库

**歌单与收藏**
- 默认歌单"我喜欢"（收藏自动汇总）
- 自定义歌单：新建 / 重命名 / 删除 / 相册封面 / 添加 / 左滑移除 / 歌单内搜索 / 歌曲上移下移排序

**用户系统（本地 Mock，预留服务端接入）**
- 登录 / 注册 / 退出
- 个人资料：昵称、性别、生日、地区、个人简介、本地头像

**数据与其它**
- 播放统计：本周播放、累计播放、最常听歌手；本地热歌榜（按播放次数）
- 最近播放记录（去重，保留 200 条）
- 后台持续播放（长时任务）+ 锁屏 / 控制中心媒体会话 + 播放通知
- 桌面歌词（应用内悬浮层，可拖拽）
- 深浅色自适应 + 主题色跟随封面取色 + 笔记本涂鸦风 UI

## 环境要求

- DevEco Studio（HarmonyOS NEXT 支持版本）
- HarmonyOS SDK 6.1.x（工程 targetSdkVersion 6.1.1(24)，compatibleSdkVersion 6.1.0(23)）
- 真机或模拟器，已配置自动签名

## 快速开始

1. DevEco Studio 打开工程根目录。
2. File → Project Structure → Signing Configs 勾选 Automatically generate signature（自动签名）。
3. 连接设备，点击 Run 'entry'。
4. 首次启动会请求通知授权（用于播放通知栏），建议允许。

工程已声明 `INTERNET` 与 `KEEP_BACKGROUND_RUNNING`（均 normal 级），无需额外 ACL 配置。

## 项目结构

```
entry/src/main/ets/
├── common/
│   └── Constants.ets            # 全局常量、AppStorage键名、播放器接口定义
├── model/                        # 数据实体（对应RDB表结构）
│   ├── Song.ets                  #   歌曲
│   ├── Playlist.ets              #   歌单（id=-1为虚拟"我喜欢"）
│   ├── DownloadTask.ets          #   下载任务
│   └── PlayHistory.ets           #   播放历史
├── utils/                        # 工具层
│   ├── Logger.ets                #   hilog统一日志
│   ├── FmtUtil.ets               #   时长/大小/速度格式化
│   ├── LrcParser.ets             #   LRC解析（逐行+增强逐字卡拉OK）
│   ├── MetaParser.ets            #   音频元数据解析（ID3v2/FLAC/WAV/M4A）
│   ├── ColorUtil.ets             #   封面主色提取
│   └── NetUtil.ets               #   网络状态检测
├── service/                      # 业务服务层
│   ├── PrefsService.ets          #   preferences偏好持久化
│   ├── DbService.ets             #   relationalStore（songs/playlists/download_tasks/play_history）
│   ├── LibraryService.ets        #   本地音乐库：扫描/导入/URI复制
│   ├── OnlineService.ets         #   在线搜索（Jamendo + 演示数据回退）
│   ├── LyricsService.ets         #   歌词获取（本地→缓存→LRCLIB→演示）
│   ├── DownloadService.ets       #   下载队列（并发≤3、断点续传、完成入库）
│   ├── AvSessionHelper.ets       #   媒体会话（锁屏/控制中心）
│   ├── PlayerService.ets         #   AVPlayer封装+长时任务+通知+队列+续播+定时关闭
│   └── UserService.ets           #   用户（本地Mock，预留服务端替换）
├── viewmodel/
│   └── AppModel.ets              # 全局ViewModel：初始化编排、数据聚合、导航、播放联动
├── view/                         # 通用组件
│   ├── CoverImage.ets            #   封面（本地/网络/占位）
│   ├── SongRow.ets               #   歌曲行（播放/序号/多选形态）
│   ├── MiniPlayerBar.ets         #   底部迷你播放条
│   ├── LyricView.ets             #   歌词视图（滚动/高亮/逐字/点击跳转）
│   ├── FloatLyrics.ets           #   桌面歌词悬浮层
│   └── dialogs/                  #   输入框/音质选择/歌单选择对话框
├── pages/
│   ├── SplashPage.ets            #   启动页
│   ├── Index.ets                 #   主框架（Navigation路由表）
│   ├── home/                     #   首页四Tab：我的音乐/在线音乐/播放列表/我的
│   ├── SearchPage.ets            #   搜索（本地/在线双模式+建议+历史）
│   ├── PlayerPage.ets            #   播放页
│   ├── LyricsPage.ets            #   歌词页
│   ├── PlaylistDetailPage.ets    #   歌单详情
│   ├── AddToPlaylistPage.ets     #   添加到歌单
│   ├── CreatePlaylistPage.ets    #   新建/重命名歌单
│   ├── PickSongsPage.ets         #   多选歌曲加入歌单
│   ├── DownloadPage.ets          #   下载管理
│   ├── SettingsPage.ets          #   设置
│   ├── LoginPage.ets             #   登录/注册（Mock）
│   ├── ProfilePage.ets           #   个人资料
│   └── MusicGroupPage.ets        #   歌手/专辑详情
└── entryability/
    └── EntryAbility.ets          # Stage模型入口
```

`art/` 目录为图标与头像的生成脚本及产出（GDI+ 脚本，与运行时无依赖）。

## 架构说明

采用 MVVM 分层，UI 不直接操作底层数据：

```
pages/view（UI，@StorageProp/Link订阅状态）
    ↓
viewmodel/AppModel（业务编排、数据聚合、Navigation）
    ↓
service/*（播放器/下载/歌词/用户/数据库/偏好）
    ↓
model + relationalStore/preferences（数据持久化）
```

- 播放状态通过 AppStorage 键发布（键名见 `Constants.ets`），UI 声明式订阅，跨页面自动刷新。
- 在线数据源集中在 `OnlineService`：Jamendo 曲库 → 自建 API → 内置演示音源三级回退；接自建后端只需改 `ONLINE_API_BASE`。

## 关键技术点

| 能力 | 实现 |
|---|---|
| 音频播放 | AVPlayer：本地 fdSrc / 网络 url 双源，seek、倍速、焦点中断处理；切歌时管理 fd 生命周期 |
| 后台播放 | backgroundTaskManager 长时任务（AUDIO_PLAYBACK）+ KEEP_BACKGROUND_RUNNING |
| 锁屏控制 | AVSession 媒体会话（元数据/播放态/播放/暂停/切歌/seek） |
| 通知栏 | notificationManager 常驻播放通知 |
| 下载 | request.agent 后台代理：队列调度、并发上限、pause/resume、完成回调入库 |
| 歌词 | LRC 解析（含 `<mm:ss.xx>` 增强逐字标签），多级数据源获取 |
| 元数据 | 纯 ArkTS 解析 ID3v2.3/2.4、FLAC（STREAMINFO/VORBIS_COMMENT/PICTURE）、WAV、M4A（mvhd/ilst） |
| 主题色 | PixelMap 降采样 + 加权饱和度统计提取封面主色 |
| 数据存储 | relationalStore 四表 + preferences（键名集中在 Constants） |

## 数据存储位置

- 数据库 / 偏好：应用沙箱（`shiqu.db`、`shiqu_prefs`）
- 下载音乐：`files/download/`（下载代理先落临时目录，完成后自动转存）
- 手动导入：`files/imported/`
- 封面 / 歌词缓存：`cache/covers/`、`cache/lyrics/`（可在设置页清理）

## 在线音源配置

`common/Constants.ets`：

| 常量 | 说明 |
|---|---|
| `JAMENDO_CLIENT_ID` | Jamendo 曲库凭证，已内置；置空则回退自建 API / 演示数据 |
| `ONLINE_API_BASE` | 自建后端地址，契约：`GET /search?keyword=` 返回 `{"data":[{id,title,artist,album,duration,url,cover,standardUrl,highUrl,losslessUrl}]}`；`GET /lyrics?title=&artist=` 返回 `{"lyrics":"[00:00.00]..."}` |
| `LRCLIB_API_BASE` | 公开歌词库，无需配置 |

搜索优先级：Jamendo（已配置 client_id）→ 自建 API → 内置演示数据。

## 常见问题

1. **compatibleSdkVersion 报不存在**：安装 6.1.0 SDK，或将 `build-profile.json5` 的 `compatibleSdkVersion` 改为 `6.1.1(24)`。
2. **在线搜索中文无结果**：Jamendo 为欧美曲库，属正常现象；换英文关键词（piano / summer / rock）体验最佳。
3. **本地歌曲时长显示 00:00**：部分格式首次播放时由 AVPlayer 上报真实时长并自动回填数据库。
4. **无法播放演示音源**：确认设备可访问外网（演示音源为 HTTPS 公开地址）。
5. **重启后歌单/收藏为空**：v1.0.0 起数据库更名为 `shiqu.db`，旧测试数据不迁移；已下载/导入的音频文件会在启动扫描时自动找回。
