# SandboxFinder

一个专为 HarmonyOS 应用开发者设计的**沙箱文件浏览器**，通过内置 HTTP 服务器提供 Web 界面访问应用沙箱目录。

## 核心特性

### 🔍 沙箱文件系统浏览
- **内置 HTTP 服务器** - 基于 `TCP Socket` 实现的轻量级 HTTP 服务器
- **多设备** - 支持模拟器和真机
- **文件类型识别** - 智能识别文本、图片、视频、音频、SQLite 数据库等文件类型
- **自定义端口** - 默认端口`7777`

### 🌐 Web 界面访问
- **响应式 Web UI** - 使用 Vue 3 + Tailwind CSS 构建的现代化界面
- **快速访问** - 提供便捷的沙箱目录访问（`filesDir`、`cacheDir`、`tempDir`、`databaseDir` 等）
- **预览** - 支持文本、图片、视频、音频、SQLite 数据库预览
- **排序** - 支持按名称、大小、时间排序
- **搜索** - 实时关键字搜索

### 📁 文件操作功能
- **基础文件操作** - 创建、删除、重命名

- **文件上传** - 支持大文件分块、批量、拖放上传

- **下载** - 直链下载







## 快速开始

### 集成到项目

1. **添加依赖**
```json5
// 项目根目录 oh-package.json5
{
  "dependencies": {
    "@cxy/sandboxfinder": "^1.0.0"
  }
}
```

2. **导入并启动**
```typescript
// EntryAbility.ets

import BuildProfile from 'BuildProfile'; //需手动编译一下你的工程

onWindowStageCreate(windowStage: window.WindowStage): void {
  windowStage.loadContent('pages/Index', (err) => {
    if (err.code) {
      return;
    }

    // 推荐只在 DEBUG 模式下使用
    if (BuildProfile.DEBUG) {
      import('@cxy/sandboxfinder').then(async (ns: ESObject) => {
        // 默认绑定到端口 7777
        ns.SandboxFinder.run().then((server: ESObject) => {
          if (server.address) {
            AppStorage.setOrCreate('server', `http://${server.address}:${server.port}`)
          }
        })
      });

      // 避免服务挂起，设置不息屏
      windowStage.getMainWindowSync().setWindowKeepScreenOn(true)
    }
  });
}



```





---

**作者**: @仙银 (@cxy)  
**版本**: 1.0.0  
**最后更新**: 2025年7月22日