import type { RTCIceServerLike } from '../shared/protocol';

// Voice goes peer to peer. STUN is enough on most home Wi-Fi, but phones on
// mobile data often sit behind carrier NAT that only a TURN relay gets
// through. Configure one of:
//
//   ICE_SERVERS='[{"urls":"turn:turn.example.com:3478","username":"u","credential":"p"}]'
//   CF_TURN_KEY_ID=...  CF_TURN_API_TOKEN=...   (Cloudflare Realtime TURN, short-lived credentials)

const PUBLIC_STUN: RTCIceServerLike[] = [{ urls: ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'] }];

let cached: { servers: RTCIceServerLike[]; until: number } | null = null;

function fromEnv(): RTCIceServerLike[] {
  const raw = process.env.ICE_SERVERS;
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [parsed];
  } catch {
    console.warn('ICE_SERVERS is not valid JSON; ignoring it.');
    return [];
  }
}

async function fromCloudflare(): Promise<RTCIceServerLike[]> {
  const keyId = process.env.CF_TURN_KEY_ID;
  const token = process.env.CF_TURN_API_TOKEN;
  if (!keyId || !token) return [];
  if (cached && cached.until > Date.now()) return cached.servers;
  try {
    const res = await fetch(`https://rtc.live.cloudflare.com/v1/turn/keys/${keyId}/credentials/generate-ice-servers`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ ttl: 86_400 }),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const body = (await res.json()) as { iceServers?: RTCIceServerLike[] | RTCIceServerLike };
    const list = Array.isArray(body.iceServers) ? body.iceServers : body.iceServers ? [body.iceServers] : [];
    // Browsers stall on TURN over port 53, which Cloudflare also offers; leave those out.
    const servers = list.map((s) => ({ ...s, urls: [s.urls].flat().filter((u) => !/:53(\?|$)/.test(u)) }));
    cached = { servers, until: Date.now() + 6 * 3_600_000 };
    return servers;
  } catch (err) {
    console.warn('Could not fetch Cloudflare TURN credentials:', (err as Error).message);
    return [];
  }
}

export async function iceServers(): Promise<RTCIceServerLike[]> {
  const extra = [...fromEnv(), ...(await fromCloudflare())];
  return [...PUBLIC_STUN, ...extra];
}

const hasTurn = (servers: RTCIceServerLike[]) => servers.some((s) => [s.urls].flat().some((u) => /^turns?:/.test(u)));

/**
 * Which relay voice can fall back on, for the status page: never the
 * credentials, only whether a TURN server is set up and answering.
 * 'error' means Cloudflare keys are set but credentials couldn't be fetched.
 */
export async function relayStatus(): Promise<'cloudflare' | 'custom' | 'none' | 'error'> {
  if (process.env.CF_TURN_KEY_ID || process.env.CF_TURN_API_TOKEN) return hasTurn(await fromCloudflare()) ? 'cloudflare' : 'error';
  return hasTurn(fromEnv()) ? 'custom' : 'none';
}
