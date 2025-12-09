/**
 * @fileName : HttpServer.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : http服务器
 */


import { connection, socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Utils } from '../utils/Utils';
import { deviceInfo } from '@kit.BasicServicesKit';

export class HttpServer {
  private tcpServer: socket.TCPSocketServer | null = null;
  private clientHandler: (requestData: Uint8Array) => Promise<string | ArrayBuffer>;
  // 定义存放客户端连接的数组
  private clients: socket.TCPSocketConnection[] = [];

  constructor(clientHandler: (requestData: Uint8Array) => Promise<string | ArrayBuffer>) {
    this.clientHandler = clientHandler;
  }

  // 启动服务器
  public async startServer(port: number): Promise<socket.NetAddress> {
    try {
      this.tcpServer = socket.constructTCPSocketServerInstance();

      // 监听连接
      this.tcpServer.on('connect', (clientSocket: socket.TCPSocketConnection) => {
        this.clients.push(clientSocket)
        this.handleClient(clientSocket);
      });

      // 监听错误
      this.tcpServer.on('error', (error: BusinessError) => {
        console.error('服务器错误:', error);
      });

      // 绑定到动态端口
      const bindAddress: socket.NetAddress = {
        address: this.getLocalIP(),
        port: port
      };
      await this.tcpServer.listen(bindAddress);
      // 获取实际的端口和地址
      const info = await this.tcpServer.getLocalAddress();
      return info
    } catch (error) {
      console.error('沙箱浏览器启动失败:', error);
      return {
        address: '',
        port: 0
      }
    }
  }

  // 停止服务器
  public async stopServer(): Promise<void> {
    try {
      this.clients.forEach(async (client, _) => {
        await client.close();
      })
      this.clients = []
      this.tcpServer?.off('connect')
      if (deviceInfo.sdkApiVersion >= 20) {
        await this.tcpServer?.close()
      }
    } catch (e) {
    }
    this.tcpServer = null;
  }

  // 处理客户端连接
  private handleClient(clientSocket: socket.TCPSocketConnection) {
    let receivedData = new ArrayBuffer(0);
    let isReceivingBody = false;
    let expectedContentLength = 0;
    let headerEndIndex = -1;

    clientSocket.on('message', async (data: socket.SocketMessageInfo) => {
      // 合并接收到的数据
      receivedData = Utils.mergeArrayBuffers(receivedData, data.message);

      if (!isReceivingBody) {
        // 查找HTTP头结束标志
        const headerStr = Utils.arrayBufferToStr(receivedData);
        headerEndIndex = headerStr.indexOf('\r\n\r\n');

        if (headerEndIndex !== -1) {
          isReceivingBody = true;
          // 解析Content-Length
          const contentLengthMatch = headerStr.match(/Content-Length:\s*(\d+)/i);
          if (contentLengthMatch) {
            expectedContentLength = parseInt(contentLengthMatch[1]);
          }
        }
      }

      // 检查是否接收完整个请求
      if (isReceivingBody) {
        const headerLength = headerEndIndex + 4; // '\r\n\r\n' 的长度
        const bodyLength = receivedData.byteLength - headerLength;

        if (bodyLength >= expectedContentLength) {

          // 处理完整数据
          let response = await this.clientHandler(new Uint8Array(receivedData));
          // response = this.addCORSHeaders(response);
          await clientSocket.send({
            data: response
          });
          return;
        }
      }

      // 如果没有Content-Length或者是GET请求，直接处理
      if (!isReceivingBody && headerEndIndex !== -1 && expectedContentLength === 0) {
        let response = await this.clientHandler(new Uint8Array(receivedData));
        // response = this.addCORSHeaders(response);
        await clientSocket.send({
          data: response
        })
      }

      clientSocket.on('error', (error: BusinessError) => {
        console.error('错误:', error);
      });

      clientSocket.on('close', () => {
        console.error('已关闭');
      });
    });
  }

  // 为响应添加CORS头
  private addCORSHeaders(response: string | ArrayBuffer): string | ArrayBuffer {
    if (typeof response === 'string') {
      // 在header后插入CORS头
      const headerEnd = response.indexOf('\r\n\r\n');
      if (headerEnd !== -1) {
        const corsHeaders =
          'Access-Control-Allow-Origin: *\r\n' +
            'Access-Control-Allow-Methods: GET,POST,PUT,DELETE,OPTIONS\r\n' +
            'Access-Control-Allow-Headers: Content-Type\r\n';
        return response.slice(0, headerEnd + 2) + corsHeaders + response.slice(headerEnd + 2);
      }
    } else if (response instanceof ArrayBuffer) {
      // 二进制响应，尝试插入CORS头
      // 先将前面部分转为字符串，插入CORS头，再拼接body

      const arr = new Uint8Array(response);
      // 查找header结束位置（\r\n\r\n）
      let headerEnd = -1;
      for (let i = 0; i < arr.length - 3; i++) {
        if (arr[i] === 13 && arr[i + 1] === 10 && arr[i + 2] === 13 && arr[i + 3] === 10) {
          headerEnd = i + 4;
          break;
        }
      }
      if (headerEnd !== -1) {
        const headerStr = Utils.uint8ToStr(arr.slice(0, headerEnd))
        const corsHeaders =
          'Access-Control-Allow-Origin: *\r\n' +
            'Access-Control-Allow-Methods: GET,POST,PUT,DELETE,OPTIONS\r\n' +
            'Access-Control-Allow-Headers: Content-Type\r\n';
        const newHeader = headerStr.replace('\r\n\r\n', '\r\n' + corsHeaders + '\r\n');
        const newHeaderBytes = Utils.strToUint8Array(newHeader);
        const bodyBytes = arr.slice(headerEnd);
        const merged = new Uint8Array(newHeaderBytes.length + bodyBytes.length);
        merged.set(newHeaderBytes, 0);
        merged.set(bodyBytes, newHeaderBytes.length);
        return merged.buffer;
      }
    }
    return response;
  }


  /**
   * 获取本地IP地址
   * @returns IP地址字符串
   */
  protected getLocalIP(): string {
    const localIP = '127.0.0.1'
    // 模拟器直接返回固定的
    if (deviceInfo.productModel === 'emulator') {
      return localIP;
    }

    try {
      const netHandle = connection.getDefaultNetSync();
      if (netHandle.netId === 0) {
        // 当前没有已连接的网络时，获取的netHandler的netid为0
        return localIP;
      }
      const connectionproperties = connection.getConnectionPropertiesSync(netHandle);
      return connectionproperties.linkAddresses[0].address.address;
    } catch (e) {
      return localIP;
    }
  }
}