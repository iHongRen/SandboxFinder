/**
 * @fileName : SandboxFinder.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : 沙箱浏览器
 */
import { FileManager } from "./manager/FileManager";
import { HttpServer } from "./server/HttpServer";
import { RequestHandler } from "./server/RequestHandler";
import { common, Context } from "@kit.AbilityKit";
import { ServerInfo } from "./models/ServerInfo";


export class SandboxFinder {
  private static instance: SandboxFinder
  private server: HttpServer;
  private fileManager: FileManager
  private requestHandler?: RequestHandler
  private port: number
  private context: Context

  /**
   * 运行服务
   * @param port  端口号，默认7777
   * @param context UIAbilityContext, 默认 getContext()
   * @returns ServerInfo =》 { address: string , port: number }
   */
  static async run(port: number = 7777,
    context: common.UIAbilityContext = getContext() as common.UIAbilityContext): Promise<ServerInfo> {
    SandboxFinder.instance = new SandboxFinder(context, port)
    return await SandboxFinder.instance.startServer()
  }

  /**
   * 停止服务
   */
  static async stop() {
    await SandboxFinder.instance.stopServer()
  }

  private constructor(context: Context, port: number) {
    this.context = context
    this.port = port
    this.fileManager = new FileManager(this.context)
    this.server = new HttpServer((req) => this.handleRequest(req))
  }

  private async handleRequest(request: Uint8Array): Promise<string | ArrayBuffer> {
    if (!this.requestHandler) {
      return 'Server not ready';
    }
    return await this.requestHandler?.handleHttpRequest(request);
  }

  // 启动服务器
  private async startServer(): Promise<ServerInfo> {
    const serverInfo = await this.server.startServer(this.port);
    if (serverInfo.address) {
      this.printServerInfo(serverInfo)
      // 创建请求处理器
      this.requestHandler = new RequestHandler(this.fileManager, serverInfo);
    }
    return serverInfo;
  }

  // 停止服务器
  private async stopServer(): Promise<void> {
    await this.server.stopServer();
  }


  printServerInfo(serverInfo: ServerInfo) {
    console.log(`
    -----------------------------------------------
    沙箱浏览器启动成功
    请浏览器访问: http://${serverInfo.address}:${serverInfo.port}
    -----------------------------------------------
    `)
  }
}