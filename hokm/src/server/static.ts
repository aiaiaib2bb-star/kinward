import fs from 'node:fs';
import type http from 'node:http';
import path from 'node:path';
import zlib from 'node:zlib';

const TYPES: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.txt': 'text/plain; charset=utf-8',
};

const COMPRESSIBLE = new Set(['.html', '.js', '.css', '.json', '.webmanifest', '.svg', '.txt']);

interface Cached {
  raw: Buffer;
  br?: Buffer;
  gzip?: Buffer;
  mtime: number;
}

const cache = new Map<string, Cached>();

function load(file: string): Cached | null {
  let stat: fs.Stats;
  try {
    stat = fs.statSync(file);
  } catch {
    return null;
  }
  if (!stat.isFile()) return null;
  const hit = cache.get(file);
  if (hit && hit.mtime === stat.mtimeMs) return hit;
  const raw = fs.readFileSync(file);
  const entry: Cached = { raw, mtime: stat.mtimeMs };
  if (COMPRESSIBLE.has(path.extname(file)) && raw.length > 1024) {
    entry.br = zlib.brotliCompressSync(raw, { params: { [zlib.constants.BROTLI_PARAM_QUALITY]: 9 } });
    entry.gzip = zlib.gzipSync(raw, { level: 9 });
  }
  cache.set(file, entry);
  return entry;
}

/** Serves the built client, falling back to index.html so links like /r/ABCD open the app. */
export function serveStatic(root: string, req: http.IncomingMessage, res: http.ServerResponse) {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405).end();
    return;
  }
  let pathname: string;
  try {
    pathname = decodeURIComponent(new URL(req.url ?? '/', 'http://x').pathname);
  } catch {
    res.writeHead(400).end();
    return;
  }
  const resolved = path.normalize(path.join(root, pathname));
  if (!resolved.startsWith(path.normalize(root))) {
    res.writeHead(403).end();
    return;
  }
  let file = resolved;
  let entry = pathname.endsWith('/') ? null : load(file);
  if (!entry) {
    if (path.extname(pathname)) {
      res.writeHead(404, { 'Content-Type': 'text/plain' }).end('Not found');
      return;
    }
    file = path.join(root, 'index.html');
    entry = load(file);
    if (!entry) {
      res.writeHead(503, { 'Content-Type': 'text/plain' }).end('The client has not been built. Run `npm run build`.');
      return;
    }
  }
  const ext = path.extname(file);
  const headers: Record<string, string> = {
    'Content-Type': TYPES[ext] ?? 'application/octet-stream',
    'Cache-Control': pathname.startsWith('/assets/') ? 'public, max-age=31536000, immutable' : 'no-cache',
    'X-Content-Type-Options': 'nosniff',
    Vary: 'Accept-Encoding',
  };
  const accept = String(req.headers['accept-encoding'] ?? '');
  let body = entry.raw;
  if (entry.br && /\bbr\b/.test(accept)) {
    body = entry.br;
    headers['Content-Encoding'] = 'br';
  } else if (entry.gzip && /\bgzip\b/.test(accept)) {
    body = entry.gzip;
    headers['Content-Encoding'] = 'gzip';
  }
  headers['Content-Length'] = String(body.length);
  res.writeHead(200, headers);
  if (req.method === 'HEAD') res.end();
  else res.end(body);
}
