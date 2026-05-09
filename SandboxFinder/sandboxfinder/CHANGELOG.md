# 鸿蒙沙箱浏览器 - [SandboxFinder](https://github.com/iHongRen/SandboxFinder)

[v2.0.0](https://github.com/iHongRen/SandboxFinder/releases/tag/v2.0.0)

- **重构**：底层 HTTP 服务器由自实现的 TCP Socket 替换为 `@cxy/webserver`，路由、中间件、静态文件服务全面升级
- **新增**：`run()` 参数改为配置对象 `SandboxFinderOptions`，支持 `port`、`address`、`rootDir`、`context`、`showSidebar`、`showAppInfo`、`showAbout` 等字段，所有字段均可选
- **新增**：`rootDir` 配置项，支持指定根目录，只暴露特定沙箱路径（如 `filesDir`、下载目录等），前端路径显示截断为相对路径
- **新增**：`showSidebar` / `showAppInfo` / `showAbout` 配置项，支持控制 Web 界面侧边栏及各区块的显示
- **新增**：`address` 配置项，支持自定义监听地址
- **优化**：路径安全校验，防止路径穿越访问 `rootDir` 之外的目录

[v1.0.5](https://github.com/iHongRen/SandboxFinder/releases/tag)

- 优化服务关闭和本机IP获取

[v1.0.4](https://github.com/iHongRen/SandboxFinder/releases/tag)

- 修改本机IP获取方式
- 优化服务关闭

[v1.0.3](https://github.com/iHongRen/SandboxFinder/tags)

- 优化文档
- 去除不用的权限

[v1.0.2](https://github.com/iHongRen/SandboxFinder/tags)

- 优化文档

[v1.0.1](https://github.com/iHongRen/SandboxFinder/tags)

- 优化打印

[v1.0.0](https://github.com/iHongRen/SandboxFinder/tags)

- 支持文本、图片、视频、音频、SQLite 数据库预览
- 支持批量上传、直链下载
- 文件新建、删除、重命名
- 支持模拟器和物理设备查看沙箱
