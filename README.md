# 鸿蒙沙箱浏览器 - [SandboxFinder](https://github.com/iHongRen/SandboxFinder)

<p align="center">
  <a href="https://github.com/iHongRen/SandboxFinder/releases/latest"><img src="https://img.shields.io/github/v/release/iHongRen/SandboxFinder?label=version&color=blue" alt="version"></a>
  <a href="https://github.com/iHongRen/SandboxFinder"><img src="https://img.shields.io/badge/License-Apache%202.0-green.svg" alt="License"></a>
  <a href="https://ihongren.github.io/donate.html"><img src="https://img.shields.io/badge/Sponsor-Donate-orange" alt="Sponsor"></a>
    <a href="hhttps://github.com/iHongRen/SandboxFinder"><img src="https://img.shields.io/github/stars/iHongRen/SandboxFinder.svg?style=social" alt="Star"></a>
</p>


快速访问鸿蒙应用沙箱目录，支持沙箱文件预览、下载、上传、删除、搜索。

![view](https://7up.pics/images/2025/07/24/view.png)

## 核心特性

### 沙箱文件系统

- **内置 HTTP 服务器** - 基于 [`@cxy/webserver`](https://github.com/iHongRen/WebServer) 的轻量级 Web 服务器
- **多设备** - 支持模拟器和真机
- **文件类型识别** - 智能识别文本、图片、视频、音频、SQLite 数据库等文件类型
- **自定义根目录** - 支持指定暴露的沙箱路径，默认展示全部沙箱目录
- **自定义端口** - 默认端口 `7777`

### Web 界面访问

- **响应式 Web UI** - 使用 Vue 3 + Tailwind CSS 构建的现代化界面
- **快速访问** - 提供便捷的沙箱目录访问（`filesDir`、`cacheDir`、`tempDir`、`databaseDir` 等）
- **预览** - 支持文本、图片、视频、音频、SQLite 数据库预览
- **排序** - 支持按名称、大小、时间排序
- **搜索** - 实时关键字搜索
- **UI 可配置** - 支持控制侧边栏、应用信息、关于区块的显示

### 文件操作功能

- **基础文件操作** - 创建、删除、重命名
- **文件上传** - 支持大文件分块、批量、拖放上传
- **下载** - 直链下载

## 快速开始

### 1. 安装

```sh
ohpm install @cxy/sandboxfinder
```

或添加依赖后同步：

```json5
// oh-package.json5
{
  "dependencies": {
    "@cxy/sandboxfinder": "^2.0.0"
  }
}
```

### 2. 启动服务

```typescript
// EntryAbility.ets
import BuildProfile from 'BuildProfile'; // 编译工程自动生成

onWindowStageCreate(windowStage: window.WindowStage): void {
  windowStage.loadContent('pages/Index', (err) => {
    if (err.code) return;

    // 推荐在 DEBUG 模式下使用 - 动态加载
    if (BuildProfile.DEBUG) {
      import('@cxy/sandboxfinder').then(async (ns: ESObject) => {
        ns.SandboxFinder.run() // 使用默认配置
      });

      // 避免服务挂起，设置不息屏
      windowStage.getMainWindowSync().setWindowKeepScreenOn(true)
    }
  });
}
```

### 3. 获取访问地址

查看打印 log，搜索 `--`，或直接查看设备 IP：设置 -> WLAN -> 已连接的 WIFI 详情 -> IP 地址。

```
----------------------------------------
沙箱浏览器启动成功
请浏览器访问: http://192.168.2.38:7777
模拟器使用需端口转换： hdc -t 127.0.0.1:5555 fport tcp:7777 tcp:7777
----------------------------------------
```

### 4. 浏览器访问

http://192.168.2.38:7777（换成你的 IP）

## 模拟器使用

沙箱浏览器开启后，模拟器需转发端口才能访问。

```sh
# 查看模拟器设备
hdc list targets   # 输出: 127.0.0.1:5555

# 转发端口 fport tcp:<localPort> tcp:<serverPort>
hdc -t 127.0.0.1:5555 fport tcp:7777 tcp:7777
# 输出: Forwardport result:OK 表示成功
```

转发成功后访问：http://127.0.0.1:7777，如果无法访问，关闭网络代理工具试试看。

> 使用 hdc 时如出现异常，可通过 `hdc kill -r` 命令终止异常进程并重启 hdc 服务。

## SandboxFinder API

### `SandboxFinder.run(options?)`

启动服务，接收一个可选配置对象，所有字段均有默认值。

```typescript
ns.SandboxFinder.run(options?: SandboxFinderOptions): Promise<socket.NetAddress>
```

### `SandboxFinder.stop()`

停止服务。

```typescript
ns.SandboxFinder.stop(): Promise<void>
```

### `SandboxFinderOptions` 配置项

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `port` | `number` | `7777` | 监听端口 |
| `address` | `string` | `''` | 监听地址，空字符串时自动获取本机 IP |
| `rootDir` | `string` | `'/'` | 根目录，`'/'` 表示暴露全部沙箱目录 |
| `context` | `UIAbilityContext` | `getContext()` | UIAbilityContext |
| `showSidebar` | `boolean` | `true` | 是否显示侧边栏 |
| `showAppInfo` | `boolean` | `true` | 是否显示侧边栏中的"应用信息"区块 |
| `showAbout` | `boolean` | `true` | 是否显示侧边栏中的"关于"区块 |

### 使用示例

**最简启动（全部默认）**

```typescript
ns.SandboxFinder.run()
```

**自定义端口和地址**

```typescript
ns.SandboxFinder.run({ port: 8080 })
```

**指定根目录 `rootDir`**

只暴露特定目录，Web 界面中路径显示为相对路径。

```typescript
// 只暴露 filesDir
ns.SandboxFinder.run({ rootDir: context.filesDir })
```

**控制 Web 界面显示**

```typescript
// 隐藏整个侧边栏
ns.SandboxFinder.run({ showSidebar: false })

// 只隐藏"应用信息"和"关于"区域，保留快捷访问
ns.SandboxFinder.run({ showAppInfo: false, showAbout: false })
```

**获取服务器信息**

```typescript
ns.SandboxFinder.run({ port: 7777 }).then((serverInfo: ESObject) => {
  // serverInfo: { address: string, port: number }
  AppStorage.setOrCreate('server', `http://${serverInfo.address}:${serverInfo.port}`)
})
```

**完整配置示例**

```typescript
import('@cxy/sandboxfinder').then(async (ns: ESObject) => {
  const context = windowStage.getMainWindowSync().getUIContext().getHostContext()
  ns.SandboxFinder.run({
    port: 7777,
    rootDir: context?.filesDir,   // 只暴露 filesDir
    context: context,
    showAppInfo: false,            // 隐藏应用信息
    showAbout: false,              // 隐藏关于
  }).then((serverInfo: ESObject) => {
    if (serverInfo.address) {
      AppStorage.setOrCreate('server', `http://${serverInfo.address}:${serverInfo.port}`)
    }
  })
})
```

---

如果是使用过程中有什么问题，欢迎提 [issues](https://github.com/iHongRen/SandboxFinder/issues)

# 作者

[@仙银](https://github.com/iHongRen)

鸿蒙开源作品，欢迎持续关注 [🌟Star](https://github.com/iHongRen/SandboxFinder) ，[💖赞助](https://ihongren.github.io/donate.html)

1、[hpack](https://github.com/iHongRen/hpack) - 鸿蒙 HarmonyOS 一键打包上传分发测试工具。

2、[Open-in-DevEco-Studio](https://github.com/iHongRen/Open-in-DevEco-Studio) - macOS 直接在 Finder 工具栏上，使用 DevEco-Studio 打开鸿蒙工程。

3、[cxy-theme](https://github.com/iHongRen/cxy-theme) - DevEco-Studio 绿色护眼背景主题。

4、[harmony-udid-tool](https://github.com/iHongRen/harmony-udid-tool) - 简单易用的 HarmonyOS 设备 UDID 获取工具，适用于非开发人员。

5、[SandboxFinder](https://github.com/iHongRen/SandboxFinder) - 鸿蒙沙箱文件浏览器，支持模拟器和真机。快速访问沙箱目录。

6、[WebServer](https://github.com/iHongRen/WebServer) - 鸿蒙轻量级Web服务器框架，类 Express.js API 风格，支持中间件，路由，静态服务。

7、[SelectableMenu](https://github.com/iHongRen/SelectableMenu) - 适用于聊天对话框中的文本选择菜单。

8、[RefreshList](https://github.com/iHongRen/RefreshList) - 功能完善的上拉下拉加载组件，支持各种自定义。
