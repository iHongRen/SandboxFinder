/**
 * @fileName : SandboxFinder.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : 沙箱浏览器
 */
import { FileManager } from "./manager/FileManager";
import { HttpServer } from "./server/HttpServer";
import { RequestHandler } from "./server/RequestHandler";
import { common } from "@kit.AbilityKit";
import { socket } from "@kit.NetworkKit";


export class SandboxFinder {
  private static instance: SandboxFinder
  private server: HttpServer;
  private fileManager: FileManager
  private requestHandler?: RequestHandler
  private port: number
  private context: common.UIAbilityContext

  /**
   * 运行服务
   * @param port  端口号，默认7777
   * @param context UIAbilityContext
   * @returns ServerInfo =》 { address: string , port: number }
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
    this.server = new HttpServer((req) => this.handleRequest(req))
  }

  private async handleRequest(request: Uint8Array): Promise<string | ArrayBuffer> {
    if (!this.requestHandler) {
      return 'Server not ready';
    }
    return await this.requestHandler?.handleHttpRequest(request);
  }

  // 启动服务器
  private async startServer(): Promise<socket.NetAddress> {
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