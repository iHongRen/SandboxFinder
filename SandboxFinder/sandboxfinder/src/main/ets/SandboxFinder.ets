/**
 * @fileName : SandboxFinder.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : 沙箱浏览器
 */
import { FileManager } from "./manager/FileManager";
import { HttpServer } from "./server/HttpServer";
import { RequestHandler } from "./server/RequestHandler";
import { Context } from "@kit.AbilityKit";
import { ServerInfo } from "./models/ServerInfo";


export class SandboxFinder {
  private static instance: SandboxFinder
  private server: HttpServer;
  private fileManager: FileManager
  private requestHandler?: RequestHandler
  private port: number
  private context: Context

  static async run(context: Context, port: number = 7777): Promise<ServerInfo> {
    SandboxFinder.instance = new SandboxFinder(context, port)
    return await SandboxFinder.instance.startServer()
  }

  static stop() {
    SandboxFinder.instance.stopServer()
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
      // 创建请求处理器
      this.requestHandler = new RequestHandler(this.fileManager, serverInfo);
    }
    return serverInfo;
  }

  // 停止服务器
  private async stopServer(): Promise<void> {
    await this.server.stopServer();
  }
}