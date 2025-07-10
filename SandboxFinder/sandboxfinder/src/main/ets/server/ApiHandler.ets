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
      // 获取参数
      const arr = url.split('?');
      const pathPart = arr[0]
      const queryString = arr[1]
      const params: Record<string, Object> = bodyParams
      if (queryString) {
        queryString.split('&').forEach(pair => {
          const arr = pair.split('=');
          const k = arr[0]
          const v = arr[1]
          params[k] = decodeURIComponent(v);
        });
      }

      // 服务器信息
      if (pathPart === '/api/server-info') {
        const serverInfo: ServerInfo = {
          address: this.serverAddress,
          port: this.serverPort,
        };
        return {
          code: 200,
          data: serverInfo
        }
      }

      if (pathPart === '/api/app-info') {
        return {
          code: 200,
          data: {
            versionCode: this.bundleInfo.versionCode,
            versionName: this.bundleInfo.versionName,
            bundleName: this.bundleInfo.name,
          }
        }
      }

      // ls: 列出目录内容
      if (pathPart === '/api/ls') {
        const dirPath = params['path'] as string || '/';
        const list = await this.fileManager.listDir(dirPath);
        return {
          code: 200,
          data: list
        }
      }

      // touch: 新建空文件
      if (pathPart === '/api/touch' && method === 'POST') {
        const filePath = params['path'] as string
        if (!filePath) {
          return {
            code: 400,
            message: 'Missing path'
          }
        }
        await this.fileManager.writeProjectFile(filePath, new ArrayBuffer(0));
        this.onFileChanged?.();
        return {
          code: 200,
          data: {
            success: true
          }
        }
      }

      // rm: 删除文件或目录
      if (pathPart === '/api/rm' && method === 'POST') {
        const filePath = params['path'] as string
        const recursive = params['recursive'] === 'true' || params['recursive'] === true;
        if (!filePath) {
          return {
            code: 400,
            message: 'Missing path'
          }
        }
        await this.fileManager.remove(filePath, recursive);
        this.onFileChanged?.();
        return {
          code: 200,
          data: {
            success: true
          }
        }
      }

      // mv: 重命名/移动
      if (pathPart === '/api/mv' && method === 'POST') {
        const src = params['src'] as string
        const dest = params['dest'] as string
        if (!src || !dest) {
          return {
            code: 400,
            message: 'Missing src or dest'
          }
        }
        await this.fileManager.move(src, dest);
        this.onFileChanged?.();
        return {
          code: 200,
          data: {
            success: true
          }
        }
      }

      // cp: 复制
      if (pathPart === '/api/cp' && method === 'POST') {
        const src = params['src'] as string
        const dest = params['dest'] as string
        const recursive = params['recursive'] === 'true' || params['recursive'] === true;
        if (!src || !dest) {
          return {
            code: 400,
            message: 'Missing src or dest'
          }
        }
        await this.fileManager.copy(src, dest, recursive);
        this.onFileChanged?.();
        return {
          code: 200,
          data: {
            success: true
          }
        }
      }

      // mkdir: 新建目录
      if (pathPart === '/api/mkdir' && method === 'POST') {
        const dirPath = params['path'] as string
        if (!dirPath) {
          return {
            code: 400,
            message: 'Missing path'
          }
        }
        await this.fileManager.mkdir(dirPath, '');
        this.onFileChanged?.();
        return {
          code: 200,
          data: {
            success: true
          }
        }
      }

      return {
        code: 404,
        message: 'API not found'
      }
    } catch (error) {
      return {
        code: 500,
        message: 'Internal Server Error'
      }
    }
  }
}