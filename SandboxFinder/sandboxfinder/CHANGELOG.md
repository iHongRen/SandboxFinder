# 鸿蒙沙箱浏览器 - [SandboxFinder](https://github.com/iHongRen/SandboxFinder)

v1.0.4

- 修改本机IP获取方式

- 优化关闭服务器

- 调整权限申请，改为用户自行在 module.json5 申请:

  ```json
  "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET"
      },
      {
        "name": "ohos.permission.GET_NETWORK_INFO"
      }
    ]
  ```

  



[v1.0.3](https://github.com/iHongRen/SandboxFinder/releases/tag/v1.0.3)

- 优化文档
- 去除不用的权限


[v1.0.2](https://github.com/iHongRen/SandboxFinder/releases/tag/v1.0.2)

优化文档



[v1.0.1](https://github.com/iHongRen/SandboxFinder/releases/tag/v1.0.1)

优化打印  



[v1.0.0](https://github.com/iHongRen/SandboxFinder/releases/tag/v1.0.0)

1、支持文本、图片、视频、音频、SQLite 数据库预览

2、支持批量上传、直链下载

3、文件新建、删除、重命名

4、支持模拟器和物理设备查看沙箱



