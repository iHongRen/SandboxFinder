/**
 * @fileName : SandboxFinder.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : 沙箱浏览器
 */
import { FileManager } from "./manager/FileManager";
import { ApiHandler } from "./server/ApiHandler";
import { common } from "@kit.AbilityKit";
import { socket } from "@kit.NetworkKit";
import { HttpServer, HttpRequest, HttpResponse } from '@cxy/webserver';

/**
 * SandboxFinder 启动配置
 */
export interface SandboxFinderOptions {
  /** 监听端口，默认 7777 */
  port?: number;
  /** 监听地址，默认自动获取本机 IP */
  address?: string;
  /** 根目录，默认 '/' 展示全部沙箱目录。传入具体路径则只暴露该目录，如 context.filesDir */
  rootDir?: string;
  /** UIAbilityContext，默认自动获取 */
  context?: common.UIAbilityContext;
  /** 是否显示侧边栏，默认 true。设为 false 时整个侧边栏隐藏 */
  showSidebar?: boolean;
  /** 是否显示侧边栏中的"应用信息"区块，默认 true */
  showAppInfo?: boolean;
  /** 是否显示侧边栏中的"关于"区块，默认 true */
  showAbout?: boolean;
}

export class SandboxFinder {
  private static instance: SandboxFinder
  private server: HttpServer;
  private fileManager: FileManager
  private options: Required<SandboxFinderOptions>

  /**
   * 运行服务
   * @param options 配置项，所有字段均可选
   * @returns socket.NetAddress => { address: string, port: number }
   *
   * @example
   * // 使用默认配置
   * SandboxFinder.run()
   *
   * @example
   * // 只暴露 filesDir，使用 8080 端口
   * SandboxFinder.run({ port: 8080, rootDir: context.filesDir })
   */
  static async run(options: SandboxFinderOptions = {}): Promise<socket.NetAddress> {
    const resolved: Required<SandboxFinderOptions> = {
      port: options.port ?? 7777,
      address: options.address ?? '',
      rootDir: options.rootDir ?? '/',
      context: options.context ?? (getContext() as common.UIAbilityContext),
      showSidebar: options.showSidebar ?? true,
      showAppInfo: options.showAppInfo ?? true,
      showAbout: options.showAbout ?? true,
    }
    SandboxFinder.instance = new SandboxFinder(resolved)
    return await SandboxFinder.instance.startServer()
  }

  /**
   * 停止服务
   */
  static async stop() {
    await SandboxFinder.instance.stopServer()
  }

  private constructor(options: Required<SandboxFinderOptions>) {
    this.options = options
    this.fileManager = new FileManager(options.context, options.rootDir)
    this.server = new HttpServer()
  }

  // 启动服务器
  private async startServer(): Promise<socket.NetAddress> {
    this.server.cors();
    this.server.auto();

    const apiHandler = new ApiHandler(this.fileManager, this.options.showSidebar, this.options.showAppInfo,
      this.options.showAbout);

    // API 路由
    this.server.post('/api/server-info', (req: HttpRequest, res: HttpResponse) => apiHandler.serverInfo(req, res));
    this.server.post('/api/app-info', (req: HttpRequest, res: HttpResponse) => apiHandler.appInfo(req, res));
    this.server.post('/api/read', (req: HttpRequest, res: HttpResponse) => apiHandler.read(req, res));
    this.server.post('/api/ls', (req: HttpRequest, res: HttpResponse) => apiHandler.ls(req, res));
    this.server.post('/api/touch', (req: HttpRequest, res: HttpResponse) => apiHandler.touch(req, res));
    this.server.post('/api/rm', (req: HttpRequest, res: HttpResponse) => apiHandler.rm(req, res));
    this.server.post('/api/mv', (req: HttpRequest, res: HttpResponse) => apiHandler.mv(req, res));
    this.server.post('/api/cp', (req: HttpRequest, res: HttpResponse) => apiHandler.cp(req, res));
    this.server.post('/api/mkdir', (req: HttpRequest, res: HttpResponse) => apiHandler.mkdir(req, res));

    // 文件上传
    this.server.post('/api/upload', async (req: HttpRequest, res: HttpResponse) => {
      try {
        const uploadedFile = req.files?.file;
        const fileName = (req.body as Record<string, string>)?.filename;
        const relPath = (req.body as Record<string, string>)?.path || '';
        const isFirst = (req.body as Record<string, string>)?.isFirst === '1';

        if (!uploadedFile || !fileName) {
          res.status(400).json({ code: 400, message: 'Missing file or filename' });
          return;
        }
        const absPath = this.fileManager.toAbsPath(relPath);
        await this.fileManager.appendFileStream(`${absPath}/${fileName}`,
          new Uint8Array(uploadedFile.data), isFirst);
        res.json({ code: 200, data: { success: true } });
      } catch (err) {
        const e = err as Error;
        res.status(500).json({ code: 500, message: e.message });
      }
    });

    // 静态文件服务必须在 API 路由之后注册，否则会拦截 /api/* 请求并返回 404
    this.server.serveStatic(this.fileManager.getServerPath());

    const serverInfo = await this.server.startServer(this.options.port, this.options.address);
    if (serverInfo.address) {
      apiHandler.setServerInfo(serverInfo);
      this.printServerInfo(serverInfo);
    }
    return serverInfo;
  }

  // 停止服务器
  private async stopServer(): Promise<void> {
    await this.server.stopServer();
  }

  printServerInfo(serverInfo: socket.NetAddress) {
    console.log(`
    ${'-'.repeat(40)}
    沙箱浏览器启动成功
    请浏览器访问: http://${serverInfo.address}:${serverInfo.port}
    模拟器使用需端口转换： hdc -t 127.0.0.1:5555 fport tcp:7777 tcp:7777

    Github：https://github.com/iHongRen/SandboxFinder
    三方库中心仓： https://ohpm.openharmony.cn/#/cn/detail/@cxy%2Fsandboxfinder
    ${'-'.repeat(40)}
    `)
  }
}
