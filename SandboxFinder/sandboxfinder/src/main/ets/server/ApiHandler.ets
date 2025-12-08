/**
 * @fileName : ApiHandler.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : API请求处理
 */

import { FileManager } from '../manager/FileManager';
import { Response } from './Response';
import { Utils } from '../utils/Utils';
import { socket } from '@kit.NetworkKit';

export class ApiHandler {
  private fileManager: FileManager;
  private serverAddress: string;
  private serverPort: number;

  constructor(fileManager: FileManager, serverInfo: socket.NetAddress) {
    this.fileManager = fileManager;
    this.serverAddress = serverInfo.address;
    this.serverPort = serverInfo.port || 0;
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
          params[kv[0]] = kv[1]
        });
      }

      const keys = Object.keys(params);
      keys.forEach(key => {
        const value = params[key]
        if (typeof value === 'string') {
          params[key] = decodeURIComponent(value.replace(/\+/g, '%20'))
        }
      });

      // 路由映射
      const routeMap: Record<string, (params: Record<string, Object>) => Promise<Response>> = {
        '/api/server-info': (params) => this.serverInfo(),
        '/api/app-info': (params) => this.appInfo(),
        '/api/read': (params) => this.read(params),
        '/api/ls': (params) => this.ls(params),
        '/api/touch': (params) => this.touch(params),
        '/api/rm': (params) => this.rm(params),
        '/api/mv': (params) => this.mv(params),
        '/api/cp': (params) => this.cp(params),
        '/api/mkdir': (params) => this.mkdir(params),
      };

      if (routeMap[pathPart]) {
        return await routeMap[pathPart](params);
      }
      return { code: 404, message: 'API not found' };
    } catch (error) {
      const err = error as Error
      return { code: 500, message: err.message };
    }
  }

  async serverInfo(): Promise<Response> {
    return {
      code: 200,
      data: { address: this.serverAddress, port: this.serverPort }
    }
  }

  async appInfo(): Promise<Response> {
    const info = await this.fileManager.getAppInfo()
    return {
      code: 200,
      data: info
    }
  }

  async read(params: Record<string, Object>): Promise<Response> {
    const filePath = params['path'] as string
    if (!filePath) {
      return { code: 400, message: 'Missing path' };
    }

    // 纯文本类型
    if (this.fileManager.isPlainText(filePath)) {
      const buffer = await this.fileManager.readFile(filePath);
      const content = Utils.uint8ToStr(new Uint8Array(buffer))
      return {
        code: 200,
        data: {
          type: 'text',
          content: content
        }
      };
    }

    // 需要静态直链的类型（媒体/其他）
    let url = ''
    const serverPath = this.fileManager.getServerPath()
    if (filePath.startsWith(serverPath)) {
      // 已在静态目录
      url = `${filePath.substring(serverPath.length)}`
    } else {
      // 拷贝到缓存，使用原文件名
      url = await this.fileManager.getOrCacheFile(filePath)
    }

    if (await this.fileManager.isImageFile(filePath)) {
      return {
        code: 200,
        data: {
          type: 'media',
          url: url,
          mediaKind: 'image'
        }
      };
    }

    const contentType = this.fileManager.getContentType(filePath);

    // sqlite 文件类型识别，前端可直接用 sql.js 解析
    if (contentType.includes('sqlite')) {
      return {
        code: 200,
        data: {
          type: 'sqlite',
          url: url
        }
      };
    }

    if (contentType.startsWith('video/')) {
      return {
        code: 200,
        data: {
          type: 'media',
          url: url,
          mediaKind: 'video'
        }
      };
    }
    if (contentType.startsWith('audio/')) {
      return {
        code: 200,
        data: {
          type: 'media',
          url: url,
          mediaKind: 'audio'
        }
      };
    }

    // 其他类型，返回可下载直链
    return {
      code: 200,
      data: {
        type: 'other',
        url: url
      }
    };
  }

  async ls(params: Record<string, Object>): Promise<Response> {
    const filePath = params['path'] as string
    const list = await this.fileManager.listDir(filePath);
    return { code: 200, data: list }
  }

  async touch(params: Record<string, Object>): Promise<Response> {
    const filePath = params['path'] as string
    if (!filePath) {
      return { code: 400, message: 'Missing path' };
    }
    await this.fileManager.writeFile(filePath, new ArrayBuffer(0));
    return { code: 200, data: { success: true } };
  }

  async rm(params: Record<string, Object>): Promise<Response> {
    const filePath = params['path'] as string
    if (!filePath) {
      return { code: 400, message: 'Missing path' };
    }
    await this.fileManager.remove(filePath);
    return { code: 200, data: { success: true } };
  }

  // 支持项目重命名的 mv
  async mv(params: Record<string, Object>): Promise<Response> {
    const src = params['src'] as string
    const dest = params['dest'] as string
    const isRename = params['rename'] === 'true';
    if (!src || !dest) {
      return { code: 400, message: 'Missing src or dest' };
    }
    // 如果是项目重命名，可以在这里加特殊处理（如日志、校验等）
    await this.fileManager.move(src, dest);
    return { code: 200, data: { success: true, rename: isRename } };
  }

  async cp(params: Record<string, Object>): Promise<Response> {
    const src = params['src'] as string
    const dest = params['dest'] as string
    if (!src || !dest) {
      return { code: 400, message: 'Missing src or dest' };
    }
    await this.fileManager.copy(src, dest);
    return { code: 200, data: { success: true } };
  }

  async mkdir(params: Record<string, Object>): Promise<Response> {
    const filePath = params['path'] as string
    if (!filePath) {
      return { code: 400, message: 'Missing path' };
    }
    await this.fileManager.mkdir(filePath, '');
    return { code: 200, data: { success: true } };
  }
}
