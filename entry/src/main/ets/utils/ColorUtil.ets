/**
 * 主题色提取工具：从专辑封面提取主色调，实现"主题色跟随封面"
 * 实现：将封面解码为小尺寸PixelMap，统计饱和度较高的像素加权平均，
 *      并把亮度钳制到可读区间，返回 #RRGGBB
 */
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import fs from '@ohos.file.fs';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from './Logger';
import { MetaParser } from './MetaParser';

export class ColorUtil {
  /**
   * 提取封面主色
   * @param src 本地文件路径或网络URL
   * @param cacheDir 网络封面临时缓存目录
   * @returns 形如 #RRGGBB 的颜色；失败返回空字符串（调用方使用默认主题色）
   */
  static async extractDominant(src: string, cacheDir: string): Promise<string> {
    let pm: image.PixelMap | null = null;
    let imgSrc: image.ImageSource | null = null;
    try {
      let path: string = src;
      if (src.startsWith('http')) {
        path = await ColorUtil.downloadToCache(src, cacheDir);
        if (!path) {
          return '';
        }
      }
      imgSrc = image.createImageSource(path);
      if (!imgSrc) {
        return '';
      }
      const opt: image.DecodingOptions = { desiredSize: { width: 24, height: 24 } };
      pm = await imgSrc.createPixelMap(opt);
      const len: number = pm.getPixelBytesNumber();
      const buf: ArrayBuffer = new ArrayBuffer(len);
      await pm.readPixelsToBuffer(buf);
      const color: string = ColorUtil.pickColor(buf);
      return color;
    } catch (err) {
      const e = err as BusinessError;
      Logger.w('ColorUtil', `取色失败: ${e.message}`);
      return '';
    } finally {
      try {
        if (pm) {
          await pm.release();
        }
        if (imgSrc) {
          await imgSrc.release();
        }
      } catch (err) {
        // 释放失败可忽略
      }
    }
  }

  /** 从RGBA像素数据中挑选主色 */
  private static pickColor(buf: ArrayBuffer): string {
    const u8: Uint8Array = new Uint8Array(buf);
    if (u8.length < 4) {
      return '';
    }
    // RGBA_8888: 4字节一个像素
    const pixelCount: number = Math.floor(u8.length / 4);
    let wr: number = 0;
    let wg: number = 0;
    let wb: number = 0;
    let weightSum: number = 0;
    let ar: number = 0;
    let ag: number = 0;
    let ab: number = 0;
    for (let i = 0; i < pixelCount; i++) {
      const r: number = u8[i * 4];
      const g: number = u8[i * 4 + 1];
      const b: number = u8[i * 4 + 2];
      ar += r;
      ag += g;
      ab += b;
      const max: number = Math.max(r, g, b);
      const min: number = Math.min(r, g, b);
      const sat: number = max === 0 ? 0 : (max - min) / max;
      const light: number = (max + min) / 510;
      // 偏爱饱和度高、中等亮度的像素（通常是封面主色）
      const score: number = sat * (0.35 + 0.65 * (1 - Math.abs(light - 0.5) * 2));
      if (score > 0.18) {
        wr += r * score;
        wg += g * score;
        wb += b * score;
        weightSum += score;
      }
    }
    let r2: number = 0;
    let g2: number = 0;
    let b2: number = 0;
    if (weightSum > 0) {
      r2 = Math.floor(wr / weightSum);
      g2 = Math.floor(wg / weightSum);
      b2 = Math.floor(wb / weightSum);
    } else {
      r2 = Math.floor(ar / pixelCount);
      g2 = Math.floor(ag / pixelCount);
      b2 = Math.floor(ab / pixelCount);
    }
    // 亮度钳制，保证在深浅两种模式下都可读
    const lum: number = 0.299 * r2 + 0.587 * g2 + 0.114 * b2;
    if (lum < 70 || lum > 190) {
      const target: number = lum < 70 ? 70 : 190;
      const f: number = target / Math.max(lum, 1);
      r2 = Math.min(255, Math.floor(r2 * f));
      g2 = Math.min(255, Math.floor(g2 * f));
      b2 = Math.min(255, Math.floor(b2 * f));
    }
    return `#${ColorUtil.hex(r2)}${ColorUtil.hex(g2)}${ColorUtil.hex(b2)}`;
  }

  private static hex(v: number): string {
    const s: string = Math.max(0, Math.min(255, v)).toString(16);
    return s.length === 1 ? `0${s}` : s;
  }

  /** 下载网络封面到缓存目录 */
  private static async downloadToCache(url: string, cacheDir: string): Promise<string> {
    try {
      MetaParser.ensureDir(cacheDir);
      const dest: string = `${cacheDir}/net_cover_${Math.abs(ColorUtil.hashOf(url))}.img`;
      const cli: http.HttpRequest = http.createHttp();
      const resp: http.HttpResponse = await cli.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 8000,
        readTimeout: 10000
      });
      if (resp.responseCode === 200) {
        const data: ArrayBuffer = resp.result as ArrayBuffer;
        if (data.byteLength > 100) {
          const f: fs.File = fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
          fs.writeSync(f.fd, data);
          fs.closeSync(f);
          cli.destroy();
          return dest;
        }
      }
      cli.destroy();
      return '';
    } catch (err) {
      const e = err as BusinessError;
      Logger.w('ColorUtil', `封面下载失败: ${e.message}`);
      return '';
    }
  }

  private static hashOf(s: string): number {
    let h: number = 0;
    for (let i = 0; i < s.length; i++) {
      h = (h * 31 + s.charCodeAt(i)) % 999999937;
    }
    return h;
  }
}
