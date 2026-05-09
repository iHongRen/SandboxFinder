/**
 * @fileName : ApiHandler.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : API请求处理
 */

import { FileManager } from '../manager/FileManager';
import { Utils } from '../utils/Utils';
import { socket } from '@kit.NetworkKit';
import { HttpRequest, HttpResponse } from '@cxy/webserver';

export class ApiHandler {
  private fileManager: FileManager;
  private serverAddress: string = '';
  private serverPort: number = 0;
  private showSidebar: boolean = true;
  private showAppInfo: boolean = true;
  private showAbout: boolean = true;

  constructor(fileManager: FileManager, showSidebar: boolean = true, showAppInfo: boolean = true,
    showAbout: boolean = true) {
    this.fileManager = fileManager;
    this.showSidebar = showSidebar;
    this.showAppInfo = showAppInfo;
    this.showAbout = showAbout;
  }

  setServerInfo(serverInfo: socket.NetAddress) {
    this.serverAddress = serverInfo.address;
    this.serverPort = serverInfo.port || 0;
  }

  async serverInfo(req: HttpRequest, res: HttpResponse): Promise<void> {
    res.json({
      code: 200,
      data: {
        address: this.serverAddress,
        port: this.serverPort,
        rootDir: this.fileManager.getRootDir(),
        showSidebar: this.showSidebar,
        showAppInfo: this.showAppInfo,
        showAbout: this.showAbout,
      }
    });
  }

  async appInfo(req: HttpRequest, res: HttpResponse): Promise<void> {
    const info = await this.fileManager.getAppInfo();
    res.json({ code: 200, data: info });
  }

  async read(req: HttpRequest, res: HttpResponse): Promise<void> {
    // 前端传相对路径，转为绝对路径操作
    const relPath = this.getBodyParam(req, 'path');
    if (!relPath) {
      res.status(400).json({ code: 400, message: 'Missing path' });
      return;
    }
    const filePath = this.fileManager.toAbsPath(relPath);

    // 纯文本类型
    if (this.fileManager.isPlainText(filePath)) {
      const buf = await this.fileManager.readFile(filePath);
      const content = Utils.uint8ToStr(new Uint8Array(buf));
      res.json({ code: 200, data: { type: 'text', content: content } });
      return;
    }

    // 需要静态直链的类型（媒体/其他）
    let url = '';
    const serverPath = this.fileManager.getServerPath();
    if (filePath.startsWith(serverPath)) {
      url = filePath.substring(serverPath.length);
    } else {
      url = await this.fileManager.getOrCacheFile(filePath);
    }

    if (await this.fileManager.isImageFile(filePath)) {
      res.json({ code: 200, data: { type: 'media', url: url, mediaKind: 'image' } });
      return;
    }

    const contentType = this.fileManager.getContentType(filePath);

    if (contentType.includes('sqlite')) {
      res.json({ code: 200, data: { type: 'sqlite', url: url } });
      return;
    }

    if (contentType.startsWith('video/')) {
      res.json({ code: 200, data: { type: 'media', url: url, mediaKind: 'video' } });
      return;
    }

    if (contentType.startsWith('audio/')) {
      res.json({ code: 200, data: { type: 'media', url: url, mediaKind: 'audio' } });
      return;
    }

    res.json({ code: 200, data: { type: 'other', url: url } });
  }

  async ls(req: HttpRequest, res: HttpResponse): Promise<void> {
    // 前端传相对路径，FileManager.listDir 内部会转换
    const dirPath = this.getBodyParam(req, 'path') || '/';
    const list = await this.fileManager.listDir(dirPath);
    res.json({ code: 200, data: list });
  }

  async touch(req: HttpRequest, res: HttpResponse): Promise<void> {
    const relPath = this.getBodyParam(req, 'path');
    if (!relPath) {
      res.status(400).json({ code: 400, message: 'Missing path' });
      return;
    }
    await this.fileManager.writeFile(this.fileManager.toAbsPath(relPath), new ArrayBuffer(0));
    res.json({ code: 200, data: { success: true } });
  }

  async rm(req: HttpRequest, res: HttpResponse): Promise<void> {
    const relPath = this.getBodyParam(req, 'path');
    if (!relPath) {
      res.status(400).json({ code: 400, message: 'Missing path' });
      return;
    }
    await this.fileManager.remove(this.fileManager.toAbsPath(relPath));
    res.json({ code: 200, data: { success: true } });
  }

  async mv(req: HttpRequest, res: HttpResponse): Promise<void> {
    const src = this.fileManager.toAbsPath(this.getBodyParam(req, 'src'));
    const dest = this.fileManager.toAbsPath(this.getBodyParam(req, 'dest'));
    const isRename = this.getBodyParam(req, 'rename') === 'true';
    if (!src || !dest) {
      res.status(400).json({ code: 400, message: 'Missing src or dest' });
      return;
    }
    await this.fileManager.move(src, dest);
    res.json({ code: 200, data: { success: true, rename: isRename } });
  }

  async cp(req: HttpRequest, res: HttpResponse): Promise<void> {
    const src = this.fileManager.toAbsPath(this.getBodyParam(req, 'src'));
    const dest = this.fileManager.toAbsPath(this.getBodyParam(req, 'dest'));
    if (!src || !dest) {
      res.status(400).json({ code: 400, message: 'Missing src or dest' });
      return;
    }
    await this.fileManager.copy(src, dest);
    res.json({ code: 200, data: { success: true } });
  }

  async mkdir(req: HttpRequest, res: HttpResponse): Promise<void> {
    const relPath = this.getBodyParam(req, 'path');
    if (!relPath) {
      res.status(400).json({ code: 400, message: 'Missing path' });
      return;
    }
    await this.fileManager.mkdir(this.fileManager.toAbsPath(relPath), '');
    res.json({ code: 200, data: { success: true } });
  }

  private getBodyParam(req: HttpRequest, key: string): string {
    return ((req.body as Record<string, string>)?.[key]) || '';
  }
}
