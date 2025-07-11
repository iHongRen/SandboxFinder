/**
 * @fileName : ApiHandler.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : API请求处理
 */

import { ServerInfo } from '../models/ServerInfo';
import { FileManager } from '../manager/FileManager';
import { Response } from './Response';
import { bundleManager } from "@kit.AbilityKit";

export class ApiHandler {
  private bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
  private fileManager: FileManager;
  private serverAddress: string;
  private serverPort: number;
  onFileChanged?: () => void

  constructor(fileManager: FileManager, serverInfo: ServerInfo) {
    this.fileManager = fileManager;
    this.serverAddress = serverInfo.address;
    this.serverPort = serverInfo.port;
  }

  public async handleApiRequest(method: string, url: string,
    bodyParams: Record<string, Object> = {}): Promise<Response> {
    try {
      // 参数解析
      const req = url.split('?');
      const pathPart = req[0] as string
      const queryString = req[1]
      const params: Record<string, Object> = bodyParams || {};
      if (queryString) {
        queryString.split('&').forEach(pair => {
          const kv = pair.split('=');
          params[kv[0]] = decodeURIComponent(kv[1]);
        });
      }

      // 路由映射
      const routeMap: Record<string, (params: Record<string, Object>) => Promise<Response>> = {
        '/api/server-info': this.serverInfo.bind(this),
        '/api/app-info': this.appInfo.bind(this),
        '/api/read': this.read.bind(this),
        '/api/ls': this.ls.bind(this),
        '/api/touch': this.touch.bind(this),
        '/api/rm': this.rm.bind(this),
        '/api/mv': this.mv.bind(this),
        '/api/cp': this.cp.bind(this),
        '/api/mkdir': this.mkdir.bind(this),
      };

      if (routeMap[pathPart]) {
        return await routeMap[pathPart](params);
      }
      return { code: 404, message: 'API not found' };
    } catch (error) {
      return { code: 500, message: String(error) };
    }
  }

  async serverInfo(): Promise<Response> {
    return {
      code: 200,
      data: { address: this.serverAddress, port: this.serverPort }
    }
  }

  async appInfo(): Promise<Response> {
    return {
      code: 200,
      data: {
        versionCode: this.bundleInfo.versionCode,
        versionName: this.bundleInfo.versionName,
        bundleName: this.bundleInfo.name,
      }
    }
  }

  async read(params: Record<string, Object>): Promise<Response> {
    const filePath = params['path'] as string;
    if (!filePath) {
      return { code: 400, message: 'Missing path' };
    }
    const content = this.fileManager.readFile(filePath)
    return { code: 200, data: { content, type: 'text' } };
  }

  async ls(params: Record<string, Object>): Promise<Response> {
    const dirPath = params['path'] as string || '/';
    const list = await this.fileManager.listDir(dirPath);
    return { code: 200, data: list }
  }

  async touch(params: Record<string, Object>): Promise<Response> {
    const filePath = params['path'] as string;
    if (!filePath) {
      return { code: 400, message: 'Missing path' };
    }
    await this.fileManager.writeFile(filePath, new ArrayBuffer(0));
    this.onFileChanged?.();
    return { code: 200, data: { success: true } };
  }

  async rm(params: Record<string, Object>): Promise<Response> {
    const filePath = params['path'] as string;
    if (!filePath) {
      return { code: 400, message: 'Missing path' };
    }
    await this.fileManager.remove(filePath);
    this.onFileChanged?.();
    return { code: 200, data: { success: true } };
  }

  // 支持项目重命名的 mv
  async mv(params: Record<string, Object>): Promise<Response> {
    const src = params['src'] as string;
    const dest = params['dest'] as string;
    const isRename = params['rename'] === 'true';
    if (!src || !dest) {
      return { code: 400, message: 'Missing src or dest' };
    }
    // 如果是项目重命名，可以在这里加特殊处理（如日志、校验等）
    await this.fileManager.move(src, dest);
    this.onFileChanged?.();
    return { code: 200, data: { success: true, rename: isRename } };
  }

  async cp(params: Record<string, Object>): Promise<Response> {
    const src = params['src'] as string;
    const dest = params['dest'] as string;
    const recursive = params['recursive'] === 'true' || params['recursive'] === true;
    if (!src || !dest) {
      return { code: 400, message: 'Missing src or dest' };
    }
    await this.fileManager.copy(src, dest, recursive);
    this.onFileChanged?.();
    return { code: 200, data: { success: true } };
  }

  async mkdir(params: Record<string, Object>): Promise<Response> {
    const dirPath = params['path'] as string;
    if (!dirPath) {
      return { code: 400, message: 'Missing path' };
    }
    await this.fileManager.mkdir(dirPath, '');
    this.onFileChanged?.();
    return { code: 200, data: { success: true } };
  }
}
