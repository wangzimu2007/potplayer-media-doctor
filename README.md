# PotPlayer Media Doctor

一个 Windows 小工具：用 `ffprobe` 检测视频的音频/视频格式，推荐 PotPlayer 音频预设，并可一键用指定配置启动 PotPlayer。

## 功能

- 拖入或选择视频文件
- 检测：
  - 分辨率、HDR/HLG/Dolby Vision、位深、帧率
  - 音频编码、声道数、采样率
- 音频预设一键启动：
  - `7.1.2`
  - `5.1`
  - `2.0`
- 画面预设：
  - 跟随 PotPlayer 预设（推荐）
  - 自动（按片源）
  - madVR 电影 SDR
  - madVR 老片 1080p
  - MPC-VR 10bit HDR
- 复制完整推荐报告

## 环境要求

- Windows 10/11
- PotPlayer 64 位
- [FFmpeg](https://ffmpeg.org/)（需要 `ffprobe.exe`）
- 可选：madVR 配置切换脚本

## 安装

1. 安装 PotPlayer。
2. 安装 FFmpeg，把 `ffprobe.exe` 加入 PATH，或复制 `media-doctor.config.example.json` 为 `media-doctor.config.json` 并填写路径。
3. 在 PotPlayer 中创建三个音频配置预设，名称必须为：

```text
7.1.2
5.1
2.0
```

建议输出通道：

```text
7.1.2 → 3/2/2+LFE - 7.1
5.1   → 3/0/2+LFE - 5.1
2.0   → 2/0/0 - 2.0 立体声
```

4. 运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\MediaDoctor.ps1
```

也可以双击 `MediaDoctor.cmd`。

## 配置

复制：

```text
media-doctor.config.example.json → media-doctor.config.json
```

字段：

| 字段 | 说明 |
|---|---|
| `ffprobe` | ffprobe.exe 完整路径，留空则查 Program Files 和 PATH |
| `potplayer` | PotPlayerMini64.exe 完整路径，留空自动查找 |
| `madvrProfileScript` | 可选，madVR profile 切换脚本路径；不用 madVR 可留空 |

`media-doctor.config.json` 已加入 `.gitignore`，不会被提交。

## 一键播放逻辑

- 选择“跟随 PotPlayer 预设”：只执行 `config="预设名"`，画面由 PotPlayer 预设自己切换。
- 选择显式画面预设：先切换 madVR/MPC-VR，再用音频预设启动。
- 使用 `config="..."` 需要 PotPlayer 内已有同名配置。

示例：

```text
PotPlayerMini64.exe "movie.mkv" /new config="7.1.2"
```

## 注意

- 本工具不修改 Windows 输出设备或空间音效。
- madVR 0.92.17 不支持 Dolby Vision 动态元数据。
- 本工具只做检测和启动，不包含任何影片资源。

## License

MIT