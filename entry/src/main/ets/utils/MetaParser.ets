/**
 * 音频元数据解析器（纯ArkTS实现，无三方依赖）
 * 支持：
 *  - MP3/AAC: ID3v2.3/v2.4 文本帧(TIT2/TPE1/TALB/TLEN) + APIC封面
 *  - FLAC:    STREAMINFO(时长) + VORBIS_COMMENT(标签) + PICTURE(封面)
 *  - WAV:     fmt / data 块计算时长
 *  - M4A:     mvhd(时长) + ilst标签(标题/歌手/专辑/封面)
 * 解析失败时回退为"文件名"策略（支持"歌手 - 标题"命名）
 */
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import { Logger } from './Logger';
import { FmtUtil } from './FmtUtil';

export class MetaResult {
  title: string = '';
  artist: string = '';
  album: string = '';
  /** 时长(毫秒)，0表示未知（播放时由AVPlayer回填） */
  duration: number = 0;
  /** 比特率(kbps) */
  bitrate: number = 0;
  /** 提取出的封面文件路径 */
  coverPath: string = '';
}

export class MetaParser {
  private static readonly HEAD_LIMIT: number = 8 * 1024 * 1024;

  /**
   * 解析音频文件元数据（同步实现，读取文件头部最多8MB）
   * @param path 文件绝对路径
   * @param coverDir 封面保存目录（不存在会自动创建）
   */
  static parseFile(path: string, coverDir: string): MetaResult {
    const r: MetaResult = new MetaResult();
    try {
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const size: number = fs.statSync(path).size;
      const headLen: number = Math.min(size, MetaParser.HEAD_LIMIT);
      const buf: ArrayBuffer = new ArrayBuffer(headLen);
      fs.readSync(file.fd, buf, { length: headLen });
      fs.closeSync(file);
      const dv: DataView = new DataView(buf);
      const ext: string = FmtUtil.extOf(path);
      const hash: number = MetaParser.hashOf(path);
      if (ext === 'wav') {
        MetaParser.parseWav(dv, r);
      } else if (ext === 'flac') {
        MetaParser.parseFlac(dv, buf, r, coverDir, hash);
      } else if (ext === 'm4a') {
        MetaParser.parseM4a(dv, r, coverDir, hash);
      } else {
        // mp3/aac/ogg 等尝试ID3v2
        MetaParser.parseId3(dv, buf, r, coverDir, hash);
      }
      // 时长兜底：按比特率估算（CBR近似）
      if (r.duration <= 0 && r.bitrate > 0) {
        r.duration = Math.floor(size * 8 / (r.bitrate * 1000) * 1000);
      }
      // 标题兜底：文件名（支持"歌手 - 标题"）
      if (!r.title) {
        const base: string = FmtUtil.baseName(path);
        const sep: number = base.indexOf(' - ');
        if (sep > 0) {
          if (!r.artist) {
            r.artist = base.substring(0, sep).trim();
          }
          r.title = base.substring(sep + 3).trim();
        } else {
          r.title = base;
        }
      }
    } catch (err) {
      Logger.w('MetaParser', `解析失败 ${path}`);
    }
    return r;
  }

  // ==================== ID3v2 ====================
  private static parseId3(dv: DataView, buf: ArrayBuffer, r: MetaResult, coverDir: string, hash: number): void {
    try {
      if (dv.byteLength < 10) {
        return;
      }
      if (dv.getUint8(0) !== 0x49 || dv.getUint8(1) !== 0x44 || dv.getUint8(2) !== 0x33) {
        return;
      }
      const ver: number = dv.getUint8(3);
      const size: number = ((dv.getUint8(6) & 0x7f) << 21) | ((dv.getUint8(7) & 0x7f) << 14) |
        ((dv.getUint8(8) & 0x7f) << 7) | (dv.getUint8(9) & 0x7f);
      const end: number = Math.min(10 + size, dv.byteLength);
      let i: number = 10;
      while (i + 10 <= end) {
        const id: string = MetaParser.ascii(dv, i, 4);
        if (!/^[A-Z0-9]{4}$/.test(id)) {
          break;
        }
        const fsize: number = ver >= 4 ? MetaParser.syncSafe(dv, i + 4) : dv.getUint32(i + 4);
        if (fsize <= 0 || i + 10 + fsize > end) {
          break;
        }
        const body: number = i + 10;
        if (id === 'TIT2') {
          r.title = MetaParser.decodeText(dv, buf, body + 1, fsize - 1, dv.getUint8(body));
        } else if (id === 'TPE1') {
          r.artist = MetaParser.decodeText(dv, buf, body + 1, fsize - 1, dv.getUint8(body));
        } else if (id === 'TALB') {
          r.album = MetaParser.decodeText(dv, buf, body + 1, fsize - 1, dv.getUint8(body));
        } else if (id === 'TLEN') {
          const t: number = parseInt(MetaParser.decodeText(dv, buf, body + 1, fsize - 1, dv.getUint8(body)));
          if (!isNaN(t) && t > 0) {
            r.duration = t;
          }
        } else if (id === 'APIC') {
          MetaParser.extractId3Cover(dv, buf, body, fsize, coverDir, hash, r);
        }
        i = body + fsize;
      }
    } catch (err) {
      // 忽略ID3解析异常
    }
  }

  private static extractId3Cover(dv: DataView, buf: ArrayBuffer, body: number, fsize: number,
    coverDir: string, hash: number, r: MetaResult): void {
    try {
      const enc: number = dv.getUint8(body);
      let p: number = body + 1;
      // MIME字符串(latin1, 0结尾)
      let mime: string = '';
      while (p < body + fsize && dv.getUint8(p) !== 0) {
        mime += String.fromCharCode(dv.getUint8(p));
        p++;
      }
      p += 1; // mime结束符
      p += 1; // 图片类型字节
      // 描述字段（UTF-16为双0结尾）
      if (enc === 1 || enc === 2) {
        while (p + 1 < body + fsize && !(dv.getUint8(p) === 0 && dv.getUint8(p + 1) === 0)) {
          p += 2;
        }
        p += 2;
      } else {
        while (p < body + fsize && dv.getUint8(p) !== 0) {
          p++;
        }
        p += 1;
      }
      const imgLen: number = body + fsize - p;
      if (imgLen > 128) {
        const extName: string = mime.indexOf('png') >= 0 ? 'png' : 'jpg';
        r.coverPath = MetaParser.saveCover(buf, p, imgLen, coverDir, hash, extName);
      }
    } catch (err) {
      // 忽略封面解析异常
    }
  }

  // ==================== FLAC ====================
  private static parseFlac(dv: DataView, buf: ArrayBuffer, r: MetaResult, coverDir: string, hash: number): void {
    try {
      if (dv.byteLength < 8 || dv.getUint8(0) !== 0x66 || dv.getUint8(1) !== 0x4c) {
        return;
      }
      let off: number = 4;
      while (off + 4 <= dv.byteLength) {
        const head: number = dv.getUint8(off);
        const type: number = head & 0x7f;
        const last: boolean = (head & 0x80) !== 0;
        const blen: number = (dv.getUint8(off + 1) << 16) | (dv.getUint8(off + 2) << 8) | dv.getUint8(off + 3);
        const body: number = off + 4;
        if (body + blen > dv.byteLength) {
          break;
        }
        if (type === 0 && blen >= 18) {
          // STREAMINFO: 采样率20bit + 声道3bit + 位深5bit + 总样本36bit
          const b10: number = dv.getUint8(body + 10);
          const b11: number = dv.getUint8(body + 11);
          const b12: number = dv.getUint8(body + 12);
          const b13: number = dv.getUint8(body + 13);
          const sampleRate: number = (b10 << 12) | (b11 << 4) | (b12 >> 4);
          const total: number = (b13 & 0x0f) * 4294967296 + dv.getUint32(body + 14);
          if (sampleRate > 0) {
            r.duration = Math.floor(total / sampleRate * 1000);
          }
        } else if (type === 4) {
          // VORBIS_COMMENT(小端)
          let p: number = body;
          const vlen: number = dv.getUint32(p, true);
          p += 4 + vlen;
          const count: number = dv.getUint32(p, true);
          p += 4;
          for (let k = 0; k < count && p + 4 <= body + blen; k++) {
            const clen: number = dv.getUint32(p, true);
            p += 4;
            if (p + clen > body + blen) {
              break;
            }
            const line: string = MetaParser.utf8(buf, p, clen);
            const eq: number = line.indexOf('=');
            if (eq > 0) {
              const key: string = line.substring(0, eq).toUpperCase();
              const val: string = line.substring(eq + 1);
              if (key === 'TITLE' && !r.title) {
                r.title = val;
              } else if (key === 'ARTIST' && !r.artist) {
                r.artist = val;
              } else if (key === 'ALBUM' && !r.album) {
                r.album = val;
              }
            }
            p += clen;
          }
        } else if (type === 6) {
          // PICTURE(大端)
          let p: number = body + 4;
          const mimeLen: number = dv.getUint32(p);
          p += 4 + mimeLen;
          const descLen: number = dv.getUint32(p);
          p += 4 + descLen + 16;
          const dataLen: number = dv.getUint32(p);
          p += 4;
          if (dataLen > 128 && p + dataLen <= dv.byteLength) {
            const mime: string = MetaParser.ascii(dv, body + 8, mimeLen);
            const extName: string = mime.indexOf('png') >= 0 ? 'png' : 'jpg';
            r.coverPath = MetaParser.saveCover(buf, p, dataLen, coverDir, hash, extName);
          }
        }
        off = body + blen;
        if (last) {
          break;
        }
      }
    } catch (err) {
      // 忽略FLAC解析异常
    }
  }

  // ==================== WAV ====================
  private static parseWav(dv: DataView, r: MetaResult): void {
    try {
      if (dv.byteLength < 12 || MetaParser.ascii(dv, 0, 4) !== 'RIFF') {
        return;
      }
      let off: number = 12;
      let byteRate: number = 0;
      let dataSize: number = 0;
      while (off + 8 <= dv.byteLength) {
        const id: string = MetaParser.ascii(dv, off, 4);
        const csize: number = dv.getUint32(off + 4, true);
        if (id === 'fmt ' && csize >= 16) {
          byteRate = dv.getUint32(off + 16, true);
        } else if (id === 'data') {
          dataSize = csize;
        }
        if (csize <= 0) {
          break;
        }
        off += 8 + csize + (csize % 2);
      }
      if (byteRate > 0 && dataSize > 0) {
        r.duration = Math.floor(dataSize / byteRate * 1000);
      }
    } catch (err) {
      // 忽略WAV解析异常
    }
  }

  // ==================== M4A ====================
  private static parseM4a(dv: DataView, r: MetaResult, coverDir: string, hash: number): void {
    try {
      MetaParser.m4aWalk(dv, 0, dv.byteLength, r, coverDir, hash, 0);
    } catch (err) {
      // 忽略M4A解析异常
    }
  }

  private static m4aWalk(dv: DataView, start: number, end: number, r: MetaResult,
    coverDir: string, hash: number, depth: number): void {
    if (depth > 6) {
      return;
    }
    let off: number = start;
    while (off + 8 <= end) {
      let asize: number = dv.getUint32(off);
      const name: string = MetaParser.ascii(dv, off + 4, 4);
      if (asize === 1) {
        // 64位长度取低32位
        asize = dv.getUint32(off + 12);
      }
      if (asize < 8 || off + asize > end) {
        break;
      }
      if (name === 'moov' || name === 'udta' || name === 'trak' || name === 'ilst') {
        MetaParser.m4aWalk(dv, off + 8, off + asize, r, coverDir, hash, depth + 1);
      } else if (name === 'meta') {
        // meta原子含4字节version/flags前缀
        MetaParser.m4aWalk(dv, off + 12, off + asize, r, coverDir, hash, depth + 1);
      } else if (name === 'mvhd') {
        const ver: number = dv.getUint8(off + 8);
        if (ver === 0) {
          const ts: number = dv.getUint32(off + 20);
          const du: number = dv.getUint32(off + 24);
          if (ts > 0 && du > 0) {
            r.duration = Math.floor(du / ts * 1000);
          }
        }
      } else if (name === '©nam' || name === '©ART' || name === '©alb' || name === 'covr') {
        const dsize: number = dv.getUint32(off + 8);
        if (dsize >= 16 && off + 8 + dsize <= end &&
          MetaParser.ascii(dv, off + 12, 4) === 'data') {
          if (name === 'covr') {
            const flags: number = dv.getUint8(off + 19);
            const extName: string = flags === 14 ? 'png' : 'jpg';
            // 直接从DataView读取图片数据写盘
            r.coverPath = MetaParser.saveCoverFromDv(dv, off + 24, dsize - 16, coverDir, hash, extName);
          } else {
            // 使用DataView读取文本
            const val: string = MetaParser.utf8Dv(dv, off + 24, dsize - 16);
            if (name === '©nam' && !r.title) {
              r.title = val;
            } else if (name === '©ART' && !r.artist) {
              r.artist = val;
            } else if (name === '©alb' && !r.album) {
              r.album = val;
            }
          }
        }
      }
      off += asize;
    }
  }

  // ==================== 通用工具 ====================
  private static ascii(dv: DataView, off: number, len: number): string {
    let s: string = '';
    for (let i = 0; i < len && off + i < dv.byteLength; i++) {
      s += String.fromCharCode(dv.getUint8(off + i));
    }
    return s;
  }

  private static syncSafe(dv: DataView, off: number): number {
    return ((dv.getUint8(off) & 0x7f) << 21) | ((dv.getUint8(off + 1) & 0x7f) << 14) |
      ((dv.getUint8(off + 2) & 0x7f) << 7) | (dv.getUint8(off + 3) & 0x7f);
  }

  /** ID3文本帧解码 enc: 0-latin1 1-utf16(带BOM) 2-utf16BE 3-utf8 */
  private static decodeText(dv: DataView, buf: ArrayBuffer, off: number, len: number, enc: number): string {
    if (len <= 0 || off + len > buf.byteLength) {
      return '';
    }
    try {
      if (enc === 1 || enc === 2) {
        let le: boolean = enc === 1;
        let start: number = off;
        let count: number = len;
        if (len >= 2) {
          const b0: number = dv.getUint8(off);
          const b1: number = dv.getUint8(off + 1);
          if (b0 === 0xff && b1 === 0xfe) {
            le = true;
            start += 2;
            count -= 2;
          } else if (b0 === 0xfe && b1 === 0xff) {
            le = false;
            start += 2;
            count -= 2;
          }
        }
        const td: util.TextDecoder = util.TextDecoder.create(le ? 'utf-16le' : 'utf-16be');
        const view: Uint8Array = new Uint8Array(buf, start, count);
        return td.decodeToString(view).replace(/\uFEFF/g, '').replace(/\u0000+$/g, '').trim();
      }
      if (enc === 0) {
        // latin1手工解码
        let s: string = '';
        for (let i = 0; i < len; i++) {
          s += String.fromCharCode(dv.getUint8(off + i));
        }
        return s.replace(/\u0000+$/g, '').trim();
      }
      // utf-8
      const td8: util.TextDecoder = util.TextDecoder.create('utf-8');
      const v8: Uint8Array = new Uint8Array(buf, off, len);
      return td8.decodeToString(v8).replace(/\u0000+$/g, '').trim();
    } catch (err) {
      return '';
    }
  }

  private static utf8(buf: ArrayBuffer, off: number, len: number): string {
    try {
      const td: util.TextDecoder = util.TextDecoder.create('utf-8');
      return td.decodeToString(new Uint8Array(buf, off, len));
    } catch (err) {
      return '';
    }
  }

  private static utf8Dv(dv: DataView, off: number, len: number): string {
    try {
      if (len <= 0 || off + len > dv.byteLength) {
        return '';
      }
      const ab: ArrayBuffer = new ArrayBuffer(len);
      const target: Uint8Array = new Uint8Array(ab);
      for (let i = 0; i < len; i++) {
        target[i] = dv.getUint8(off + i);
      }
      const td: util.TextDecoder = util.TextDecoder.create('utf-8');
      return td.decodeToString(target).replace(/\u0000+$/g, '').trim();
    } catch (err) {
      return '';
    }
  }

  private static hashOf(path: string): number {
    let h: number = 0;
    for (let i = 0; i < path.length; i++) {
      h = (h * 31 + path.charCodeAt(i)) % 999999937;
    }
    return Math.abs(h);
  }

  private static saveCover(buf: ArrayBuffer, off: number, len: number,
    coverDir: string, hash: number, extName: string): string {
    try {
      MetaParser.ensureDir(coverDir);
      const dest: string = `${coverDir}/c${hash}.${extName}`;
      const data: ArrayBuffer = buf.slice(off, off + len);
      const f: fs.File = fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(f.fd, data);
      fs.closeSync(f);
      return dest;
    } catch (err) {
      return '';
    }
  }

  private static saveCoverFromDv(dv: DataView, off: number, len: number,
    coverDir: string, hash: number, extName: string): string {
    try {
      if (len <= 0 || off + len > dv.byteLength) {
        return '';
      }
      MetaParser.ensureDir(coverDir);
      const dest: string = `${coverDir}/c${hash}.${extName}`;
      const ab: ArrayBuffer = new ArrayBuffer(len);
      const target: Uint8Array = new Uint8Array(ab);
      for (let i = 0; i < len; i++) {
        target[i] = dv.getUint8(off + i);
      }
      const f: fs.File = fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(f.fd, ab);
      fs.closeSync(f);
      return dest;
    } catch (err) {
      return '';
    }
  }

  static ensureDir(dir: string): void {
    try {
      if (dir && !fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
    } catch (err) {
      // 目录可能已被并发创建
    }
  }
}
