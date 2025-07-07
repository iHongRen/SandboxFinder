/**
 * @fileName : Utils.ets
 * @author : @cxy
 * @date : 2025/7/7
 * @description : 工具类
 */

import { util } from "@kit.ArkTS";

export class Utils {
  static arrayBufferToStr(arr: ArrayBuffer): string {
    const uint8Array = new Uint8Array(arr)
    return Utils.uint8ToStr(uint8Array)
  }

  static uint8ToStr(arr: Uint8Array): string {
    return util.TextDecoder.create().decodeToString(arr)
  }

  static strToUint8Array(str: string): Uint8Array {
    return util.TextEncoder.create().encodeInto(str)
  }

  static strToArrayBuffer(str: string): ArrayBuffer {
    return Utils.strToUint8Array(str).buffer
  }

  // 工具方法：合并ArrayBuffer
  static mergeArrayBuffers(buffer1: ArrayBuffer, buffer2: ArrayBuffer): ArrayBuffer {
    const merged = new ArrayBuffer(buffer1.byteLength + buffer2.byteLength);
    const mergedView = new Uint8Array(merged);
    mergedView.set(new Uint8Array(buffer1), 0);
    mergedView.set(new Uint8Array(buffer2), buffer1.byteLength);
    return merged;
  }
}