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


export class SandboxFinder {
  private static instance: SandboxFinder
  private server: HttpServer;
  private fileManager: FileManager
  private port: number
  private context: common.UIAbilityContext

  /**
   * 运行服务
   * @param port  端口号，默认7777
   * @param context UIAbilityContext
   * @returns socket.NetAddress =》 { address: string , port: number }
   */
  static async run(port: number = 7777,
    context: common.UIAbilityContext = getContext() as common.UIAbilityContext): Promise<socket.NetAddress> {
    SandboxFinder.instance = new SandboxFinder(context, port)
    return await SandboxFinder.instance.startServer()
  }

  /**
   * 停止服务
   */
  static async stop() {
    await SandboxFinder.instance.stopServer()
  }

  private constructor(context: common.UIAbilityContext, port: number) {
    this.context = context
    this.port = port
    this.fileManager = new FileManager(this.context)
    this.server = new HttpServer()
  }

  // 启动服务器
  private async startServer(): Promise<socket.NetAddress> {
    this.server.cors();
    this.server.auto();
    this.server.serveStatic(this.fileManager.getServerPath());

    const apiHandler = new ApiHandler(this.fileManager);

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
        const path = (req.body as Record<string, string>)?.path || '';
        const isFirst = (req.body as Record<string, string>)?.isFirst === '1';

        if (!uploadedFile || !fileName) {
          res.status(400).json({ code: 400, message: 'Missing file or filename' });
          return;
        }
        await this.fileManager.appendFileStream(`${path}/${fileName}`,
          new Uint8Array(uploadedFile.data), isFirst);
        res.json({ code: 200, data: { success: true } });
      } catch (err) {
        const e = err as Error;
        res.status(500).json({ code: 500, message: e.message });
      }
    });

    const serverInfo = await this.server.startServer(this.port);
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
