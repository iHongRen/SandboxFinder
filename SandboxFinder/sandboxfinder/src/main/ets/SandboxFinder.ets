/**
 * @fileName : SandboxFinder.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : 沙盒查看器
 */
import { FileManager } from "./manager/FileManager";
import { HttpServer } from "./server/HttpServer";
import { RequestHandler } from "./server/RequestHandler";
import { AbilityLifecycleCallback, Context } from "@kit.AbilityKit";


export class SandboxFinder {
  static instance: SandboxFinder

  private server: HttpServer;
  private fileManager: FileManager
  private requestHandler?: RequestHandler
  private port: number
  private context: Context
  onFileChanged?: () => void
  lifecycleId: number = 0

  static start(context: Context, port:number=7777) {
    SandboxFinder.instance = new SandboxFinder(context, port)
    SandboxFinder.instance.start()
  }

  constructor(context: Context, port:number) {
    this.context = context
    this.port = port
    this.fileManager = new FileManager(context)
    this.server = new HttpServer((req) => this.handleRequest(req))
    this.onLife()
  }

  onLife() {
   const lifecycleCallback: AbilityLifecycleCallback = {
      onAbilityCreate(ability) {},
      onWindowStageCreate(ability, windowStage) {
        this.start()
      },
      onWindowStageActive(ability, windowStage) {},
      onWindowStageInactive(ability, windowStage) {},
      onWindowStageDestroy(ability, windowStage) {
        this.stop()
      },
      onAbilityDestroy(ability) {},
      onAbilityForeground(ability) {},
      onAbilityBackground(ability) {},
      onAbilityContinue(ability) {},
    }
    const applicationContext = this.context.getApplicationContext();
    try {
      this.lifecycleId = applicationContext.on('abilityLifecycle', lifecycleCallback);
    } catch (paramError) {
    }
  }

  offLife() {
    const applicationContext = this.context.getApplicationContext();
    try {
      applicationContext.off('abilityLifecycle', this.lifecycleId, (error, data) => {});
    } catch (paramError) {
    }
  }

  async handleRequest(request: Uint8Array): Promise<string | ArrayBuffer> {
    if (!this.requestHandler) {
      return 'Server not ready';
    }
    return await this.requestHandler?.handleHttpRequest(request);
  }

  // 启动服务器
  public async start() {
    const serverInfo = await this.server.startServer(this.port);
    if (serverInfo) {
      // 创建请求处理器
      this.requestHandler = new RequestHandler(this.fileManager, serverInfo);
      this.requestHandler.onFileChanged = () => {
        this.onFileChanged?.()
      }
    }
    return serverInfo;
  }

  // 停止服务器
  public async stop(): Promise<void> {
    await this.server.stopServer();
  }
}