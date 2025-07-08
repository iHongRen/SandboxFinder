/**
 * @fileName : RequestHandler.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : HTTP请求处理相关逻辑
 */


import fs from '@ohos.file.fs';
import { buffer, util } from '@kit.ArkTS';
import { ServerInfo } from '../models/ServerInfo';
import { FileManager } from '../manager/FileManager';
import { Utils } from '../utils/Utils';

export class RequestHandler {
  private fileManager: FileManager;
  private serverAddress: string;
  private serverPort: number;
  onFileChanged?: () => void

  constructor(fileManager: FileManager, serverInfo: ServerInfo) {
    this.fileManager = fileManager;
    this.serverAddress = serverInfo.address;
    this.serverPort = serverInfo.port;
  }

  // 解析 HTTP 头部
  private parseHeaders(headersStr: string): Record<string, string> {
    const headers: Record<string, string> = {};
    const lines = headersStr.split('\r\n')

    for (const line of lines) {
      if (!line) {
        continue;
      }
      const list = line.split(': ', 2);
      headers[list[0].toLowerCase()] = list[1];
    }
    return headers;
  }

  // 处理HTTP请求
  public async handleHttpRequest(data: Uint8Array): Promise<string | ArrayBuffer> {

    const decoder = util.TextDecoder.create()
    const requestData = decoder.decodeToString(data);
    const headersStr = requestData.split('\r\n\r\n')[0]
    const lines = headersStr.split('\r\n');
    const firstLine = lines[0]
    const firstList = firstLine.split(' ');
    const method = firstList[0]
    const url = firstList[1]

    // 提取头部和主体
    const headersLines = lines.slice(1); // 跳过请求行
    const headers = this.parseHeaders(headersLines.join('\r\n'));

    const contentType = headers['content-type'];
    if (contentType?.includes('multipart/form-data')) {
      // 处理文件上传
      if (url === '/api/upload' && method === 'POST') {
        return await this.handleMultipart(data, contentType)
      }
    }

    // 处理API请求
    if (url.startsWith('/api/')) {
      return await this.handleApiRequest(method, url);
    }

    // 处理静态文件请求
    return await this.handleStaticFileRequest(url);
  }

  private async handleMultipart(data: Uint8Array, contentType: string): Promise<string | ArrayBuffer> {

    const boundary = this.extractBoundary(contentType);
    const formData = await this.parseMultipartFormData(data, boundary);

    // 获取文件和文件名
    const fileData = formData.get('file') as ArrayBuffer;
    const fileName = formData.get('filename') as string;

    if (fileData && fileName) {
      try {
        await this.fileManager.writeProjectFile(fileName, fileData);
        this.onFileChanged?.()
        return this.createHttpResponse(200, JSON.stringify({ success: true }), 'application/json');
      } catch (err) {
        return this.createHttpResponse(500, 'File save failed');
      }
    }

    return this.createHttpResponse(500, 'failed');
  }

  // 解析 multipart/form-data
  private async parseMultipartFormData(data: Uint8Array,
    boundary: string): Promise<Map<string, string | ArrayBuffer>> {

    const formData = new Map<string, string | ArrayBuffer>();
    if (!boundary) {
      return formData;
    }

    const buff = buffer.from(data)

    // 构建boundary标记
    const boundaryPrefix = `--${boundary}`;
    const boundarySuffix = `--${boundary}--`;

    const preBuffer = buffer.from(boundaryPrefix);

    // 查找文件内容的起始和结束位置
    const startIndex = buff.indexOf(boundaryPrefix) + preBuffer.length;
    const endIndex = buff.indexOf(boundarySuffix, startIndex)

    if (startIndex === -1 || endIndex === -1) {
      return formData;
    }

    // 提取文件部分
    const filePart = buff.subarray(startIndex, endIndex);

    // 查找文件名
    const filenameStart = filePart.indexOf('filename="') + 10;
    const filenameEnd = filePart.indexOf('"', filenameStart);
    const filename = filePart.toString('utf8', filenameStart, filenameEnd);

    // 查找文件内容的起始位置 (跳过头部)
    const contentStart = filePart.indexOf('\r\n\r\n') + 4;
    const content = filePart.subarray(contentStart);
    formData.set('file', content.buffer);
    formData.set('filename', filename);

    return formData;
  }

  // 提取 multipart 边界符
  private extractBoundary(contentType: string): string {
    const match = /boundary=([^;]+)/.exec(contentType);
    return match ? `${match[1]}` : '';
  }

  // 处理静态文件请求
  private async handleStaticFileRequest(url: string): Promise<string | ArrayBuffer> {
    try {
      let filePath = url === '/' ? '/index.html' : url;
      filePath = this.fileManager.getServerPath() + filePath.replace(/\.\./g, '');

      // 检查文件是否存在
      const exists = await this.fileManager.checkFileExists(filePath);
      if (!exists) {
        return this.createHttpResponse(404, 'File not found');
      }

      // 读取文件内容
      const file = await fs.open(filePath, fs.OpenMode.READ_ONLY);
      const stat = await fs.stat(filePath);
      const buffer = new ArrayBuffer(stat.size);
      await fs.read(file.fd, buffer);
      await fs.close(file.fd);

      // 获取文件的MIME类型
      const contentType = this.fileManager.getContentType(filePath);

      return this.createHttpResponse(200, buffer, contentType);
    } catch (error) {
      console.error('读取文件失败:', error);
      return this.createHttpResponse(500, 'Internal Server Error');
    }
  }

  // 创建HTTP响应
  private createHttpResponse(statusCode: number, body: string | ArrayBuffer,
    contentType: string = 'text/html'): string | ArrayBuffer {
    const statusText = statusCode === 200 ? 'OK' :
      statusCode === 404 ? 'Not Found' :
        statusCode === 500 ? 'Internal Server Error' : 'Unknown';

    let bodyLength = typeof body === 'string' ? buffer.byteLength(body, 'utf8') : body.byteLength;

    let response = `HTTP/1.1 ${statusCode} ${statusText}\r\n` +
      `Content-Type: ${contentType}; charset=utf-8\r\n` +
      `Content-Length: ${bodyLength}\r\n` +
      `Connection: close\r\n` +
      `\r\n`;

    if (typeof body === 'string') {
      return response += body;
    } else {
      const headersBuffer = Utils.strToUint8Array(response);
      const responseBuffer = new Uint8Array(headersBuffer.byteLength + body.byteLength);

      responseBuffer.set(headersBuffer, 0);
      responseBuffer.set(new Uint8Array(body), headersBuffer.byteLength);
      return responseBuffer.buffer
    }

  }

  // 处理API请求
  private async handleApiRequest(method: string, url: string): Promise<string | ArrayBuffer> {
    try {
      // 1. 获取参数
      const arr = url.split('?');
      const pathPart = arr[0]
      const queryString = arr[1]
      const params: Record<string, string> = {};
      if (queryString) {
        queryString.split('&').forEach(pair => {
          const arr = pair.split('=');
          const k = arr[0]
          const v = arr[1]
          params[k] = decodeURIComponent(v);
        });
      }

      // 2. 路由API
      if (pathPart === '/api/server-info') {
        const serverInfo: ServerInfo = {
          address: this.serverAddress,
          port: this.serverPort,
        };
        return this.createHttpResponse(200, JSON.stringify(serverInfo), 'application/json');
      }

      // ls: 列出目录内容
      if (pathPart === '/api/ls' && method === 'GET') {
        const dirPath = params['path'] || '/';
        const list = await this.fileManager.listDir(dirPath);
        return this.createHttpResponse(200, JSON.stringify(list), 'application/json');
      }

      // cat: 读取文件内容
      // if (pathPart === '/api/cat' && method === 'GET') {
      //   const filePath = params['path'];
      //   if (!filePath) {
      //     return this.createHttpResponse(400, 'Missing path');
      //   }
      //   const content = await this.fileManager.readFileContent(filePath);
      //   return this.createHttpResponse(200, content, 'text/plain');
      // }

      // touch: 新建空文件
      if (pathPart === '/api/touch' && method === 'POST') {
        const filePath = params['path'];
        if (!filePath) {
          return this.createHttpResponse(400, 'Missing path');
        }
        await this.fileManager.writeProjectFile(filePath, new ArrayBuffer(0));
        this.onFileChanged?.();
        return this.createHttpResponse(200, JSON.stringify({ success: true }), 'application/json');
      }

      // rm: 删除文件或目录
      if (pathPart === '/api/rm' && method === 'POST') {
        const filePath = params['path'];
        const recursive = params['recursive'] === 'true';
        if (!filePath) {
          return this.createHttpResponse(400, 'Missing path');
        }
        await this.fileManager.remove(filePath, recursive);
        this.onFileChanged?.();
        return this.createHttpResponse(200, JSON.stringify({ success: true }), 'application/json');
      }

      // mv: 重命名/移动
      if (pathPart === '/api/mv' && method === 'POST') {
        const src = params['src'];
        const dest = params['dest'];
        if (!src || !dest) {
          return this.createHttpResponse(400, 'Missing src or dest');
        }
        await this.fileManager.move(src, dest);
        this.onFileChanged?.();
        return this.createHttpResponse(200, JSON.stringify({ success: true }), 'application/json');
      }

      // cp: 复制
      if (pathPart === '/api/cp' && method === 'POST') {
        const src = params['src'];
        const dest = params['dest'];
        const recursive = params['recursive'] === 'true';
        if (!src || !dest) {
          return this.createHttpResponse(400, 'Missing src or dest');
        }
        await this.fileManager.copy(src, dest, recursive);
        this.onFileChanged?.();
        return this.createHttpResponse(200, JSON.stringify({ success: true }), 'application/json');
      }

      // mkdir: 新建目录
      if (pathPart === '/api/mkdir' && method === 'POST') {
        const dirPath = params['path'];
        if (!dirPath) {
          return this.createHttpResponse(400, 'Missing path');
        }
        await this.fileManager.mkdir(dirPath, '');
        this.onFileChanged?.();
        return this.createHttpResponse(200, JSON.stringify({ success: true }), 'application/json');
      }

      // write: 写入/覆盖文件内容
      // if (pathPart === '/api/write' && method === 'POST') {
      //   const filePath = params['path'];
      //   const content = params['content'] || '';
      //   if (!filePath) {
      //     return this.createHttpResponse(400, 'Missing path');
      //   }
      //   await this.fileManager.writeProjectFile(filePath, Utils.strToUint8Array(content).buffer);
      //   this.onFileChanged?.();
      //   return this.createHttpResponse(200, JSON.stringify({ success: true }), 'application/json');
      // }

      return this.createHttpResponse(404, 'API not found');
    } catch (error) {
      return this.createHttpResponse(500, 'Internal Server Error');
    }
  }
}
