import type { RoomView } from '../../shared/protocol';
import { sfx } from '../audio/sfx';
import { t } from '../i18n';
import { net, socket } from '../net/socket';
import { app, toast } from '../state/app';
import { settings } from '../state/settings';
import { createStore, useStore } from '../state/store';

// Voice is peer to peer: everyone in voice opens one audio connection to
// everyone else (fine for a table of four or a few watchers). The server
// only relays the WebRTC handshake. Negotiation follows the "perfect
// negotiation" pattern, so it doesn't matter who starts — two phones that
// both offer at once sort themselves out.

export interface VoiceState {
  joined: boolean;
  /** We hold a microphone track (it can still be switched off). */
  hasMic: boolean;
  micOn: boolean;
  speaking: Record<string, boolean>;
  muted: Record<string, boolean>;
  /** The browser blocked playback until the next tap. */
  needsTap: boolean;
}

export const voice = createStore<VoiceState>({ joined: false, hasMic: false, micOn: false, speaking: {}, muted: {}, needsTap: false });

export function useVoice<U>(selector: (s: VoiceState) => U): U {
  return useStore(voice, selector);
}

/**
 * Every connection carries a generation number. If one stalls, the side that
 * doesn't yield in negotiation rebuilds it with the next number, and the other
 * side rebuilds its end as soon as it sees that number.
 */
type Signal = { gen?: number; description?: RTCSessionDescriptionInit; candidate?: RTCIceCandidateInit };

class Peer {
  readonly pc: RTCPeerConnection;
  readonly audio: HTMLAudioElement;
  readonly createdAt = Date.now();
  private makingOffer = false;
  private ignoreOffer = false;
  private pendingCandidates: RTCIceCandidateInit[] = [];
  private stream: MediaStream | null = null;
  private analyser: AnalyserNode | null = null;
  private failedAt = 0;

  constructor(
    readonly id: string,
    readonly polite: boolean,
    readonly gen: number,
    local: MediaStream | null,
    iceServers: RTCIceServer[],
    mesh: Mesh,
  ) {
    this.pc = new RTCPeerConnection({ iceServers });
    if (local) for (const track of local.getAudioTracks()) this.pc.addTrack(track, local);
    else this.pc.addTransceiver('audio', { direction: 'recvonly' });

    this.audio = document.createElement('audio');
    this.audio.autoplay = true;
    this.audio.setAttribute('playsinline', '');
    this.audio.muted = !!voice.get().muted[id];
    mesh.audioHost().appendChild(this.audio);

    this.pc.onnegotiationneeded = () => void this.offer();
    this.pc.onicecandidate = ({ candidate }) => {
      if (candidate) this.send({ candidate: candidate.toJSON() });
    };
    this.pc.ontrack = (e) => {
      const stream = e.streams[0] ?? new MediaStream([e.track]);
      this.stream = stream;
      this.audio.srcObject = stream;
      this.play();
      this.analyser = mesh.analyse(stream);
    };
    this.pc.onconnectionstatechange = () => {
      // A network change: try a fresh set of routes, but don't spin if the network is simply gone.
      if (this.pc.connectionState === 'failed' && Date.now() - this.failedAt > 5000) {
        this.failedAt = Date.now();
        this.pc.restartIce?.();
      }
    };
  }

  private send(data: Signal) {
    net.voiceSignal(this.id, { ...data, gen: this.gen });
  }

  private async offer() {
    try {
      this.makingOffer = true;
      const offer = await this.pc.createOffer();
      // An offer from the other side may have arrived meanwhile; then answering it comes first.
      if (this.pc.signalingState !== 'stable') return;
      await this.pc.setLocalDescription(offer);
      this.send({ description: this.pc.localDescription!.toJSON() });
    } catch (err) {
      // Losing a race with the other side's offer is normal; that offer gets answered instead.
      if ((err as Error).name !== 'InvalidStateError') console.warn('voice offer failed', err);
    } finally {
      this.makingOffer = false;
    }
  }

  async handle({ description, candidate }: Signal) {
    try {
      if (description) {
        const collision = description.type === 'offer' && (this.makingOffer || this.pc.signalingState !== 'stable');
        this.ignoreOffer = !this.polite && collision;
        if (this.ignoreOffer) return;
        if (description.type === 'answer' && this.pc.signalingState !== 'have-local-offer') return;
        // Only an offer we've actually set can be rolled back.
        if (collision && this.pc.signalingState === 'have-local-offer') await this.pc.setLocalDescription({ type: 'rollback' });
        await this.pc.setRemoteDescription(description);
        if (description.type === 'offer') {
          const answer = await this.pc.createAnswer();
          await this.pc.setLocalDescription(answer);
          this.send({ description: this.pc.localDescription!.toJSON() });
        }
        const queued = this.pendingCandidates;
        this.pendingCandidates = [];
        for (const c of queued) await this.pc.addIceCandidate(c).catch(() => {});
      } else if (candidate) {
        if (!this.pc.remoteDescription) {
          this.pendingCandidates.push(candidate);
          return;
        }
        try {
          await this.pc.addIceCandidate(candidate);
        } catch (err) {
          if (!this.ignoreOffer) throw err;
        }
      }
    } catch (err) {
      console.warn('voice signal failed', err);
    }
  }

  /** Still not talking after this long: something was lost on the way. */
  stuck(): boolean {
    const state = this.pc.connectionState;
    return (state === 'new' || state === 'connecting' || state === 'failed') && Date.now() - this.createdAt > 9000;
  }

  play() {
    this.audio.play().then(
      () => voice.set({ needsTap: false }),
      () => voice.set({ needsTap: true }),
    );
  }

  level(): number {
    return this.analyser ? rms(this.analyser) : 0;
  }

  get hasStream() {
    return !!this.stream;
  }

  close() {
    this.pc.onconnectionstatechange = null;
    this.pc.onnegotiationneeded = null;
    this.pc.close();
    this.audio.srcObject = null;
    this.audio.remove();
  }
}

const buffer = new Uint8Array(512);

function rms(analyser: AnalyserNode): number {
  analyser.getByteTimeDomainData(buffer);
  let sum = 0;
  for (let i = 0; i < analyser.fftSize; i++) {
    const v = (buffer[i] - 128) / 128;
    sum += v * v;
  }
  return Math.sqrt(sum / analyser.fftSize);
}

class Mesh {
  private local: MediaStream | null = null;
  private localAnalyser: AnalyserNode | null = null;
  private readonly peers = new Map<string, Peer>();
  private host: HTMLDivElement | null = null;
  private meterTimer: number | null = null;
  private smoothed: Record<string, number> = {};
  private serverKnowsUs = false;

  constructor() {
    socket.on('voice:signal', ({ from, data }) => {
      if (!voice.get().joined) return;
      const room = app.get().room;
      if (!room || !room.members.some((m) => m.id === from)) return;
      const signal = data as Signal;
      const gen = signal.gen ?? 0;
      let peer = this.peers.get(from);
      if (peer && gen < peer.gen) return;
      // A newer generation means the other side rebuilt the connection; rebuild ours to match.
      // (The server only relays between two people in voice, so this can also be the first
      // we hear of someone, a moment before the room update that shows them joining.)
      if (!peer || gen > peer.gen) {
        peer?.close();
        peer = this.open(from, room.you, gen);
      }
      void peer.handle(signal);
    });
    // Rebuild connections that never got going. Only the side that doesn't yield does it.
    window.setInterval(() => {
      const room = app.get().room;
      if (!voice.get().joined || !room) return;
      for (const [id, p] of this.peers) {
        if (!p.polite && p.stuck()) {
          p.close();
          this.open(id, room.you, p.gen + 1);
        }
      }
    }, 3000);
    app.subscribe(() => this.sync(app.get().room));
    // Retry blocked playback on the next touch anywhere.
    window.addEventListener('pointerdown', () => {
      if (voice.get().needsTap) for (const p of this.peers.values()) p.play();
    });
  }

  audioHost(): HTMLDivElement {
    if (!this.host) {
      this.host = document.createElement('div');
      this.host.style.display = 'none';
      document.body.appendChild(this.host);
    }
    return this.host;
  }

  analyse(stream: MediaStream): AnalyserNode | null {
    const ctx = sfx.context;
    if (!ctx) return null;
    try {
      const src = ctx.createMediaStreamSource(stream);
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 512;
      src.connect(analyser);
      return analyser;
    } catch {
      return null;
    }
  }

  async join() {
    if (voice.get().joined) return;
    if (!('RTCPeerConnection' in window)) return toast(t('voice_unsupported'), 'bad');
    if (!window.isSecureContext) return toast(t('voice_needs_https'), 'bad', 4000);
    sfx.unlock();
    try {
      this.local = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
      });
    } catch {
      this.local = null;
      toast(t('mic_blocked'), 'bad', 4000);
    }
    const micOn = !!this.local && settings.get().voiceMode === 'open';
    this.local?.getAudioTracks().forEach((tr) => (tr.enabled = micOn));
    this.localAnalyser = this.local ? this.analyse(this.local) : null;
    voice.set({ joined: true, hasMic: !!this.local, micOn });
    this.serverKnowsUs = false;
    net.voiceJoin();
    net.voiceMic(micOn);
    this.startMeter();
    sfx.play('chime');
    this.sync(app.get().room);
  }

  leave() {
    if (!voice.get().joined) return;
    for (const p of this.peers.values()) p.close();
    this.peers.clear();
    this.local?.getTracks().forEach((tr) => tr.stop());
    this.local = null;
    this.localAnalyser = null;
    if (this.meterTimer) clearInterval(this.meterTimer);
    this.meterTimer = null;
    voice.set({ joined: false, hasMic: false, micOn: false, speaking: {}, needsTap: false });
    net.voiceLeave();
  }

  setMic(on: boolean) {
    if (!this.local) return;
    this.local.getAudioTracks().forEach((tr) => (tr.enabled = on));
    voice.set({ micOn: on });
    net.voiceMic(on);
  }

  toggleMute(id: string) {
    const muted = { ...voice.get().muted, [id]: !voice.get().muted[id] };
    voice.set({ muted });
    const p = this.peers.get(id);
    if (p) p.audio.muted = !!muted[id];
  }

  /** Connection state per peer, for tests and troubleshooting. */
  debug(): Record<string, { connection: RTCPeerConnectionState; ice: RTCIceConnectionState; receiving: boolean }> {
    const out: Record<string, { connection: RTCPeerConnectionState; ice: RTCIceConnectionState; receiving: boolean }> = {};
    for (const [id, p] of this.peers) out[id] = { connection: p.pc.connectionState, ice: p.pc.iceConnectionState, receiving: p.hasStream };
    return out;
  }

  private open(id: string, me: string, gen = 0): Peer {
    const peer = new Peer(id, me > id, gen, this.local, app.get().iceServers as RTCIceServer[], this);
    this.peers.set(id, peer);
    return peer;
  }

  /** Brings the set of connections in line with who the server says is in voice. */
  private sync(room: RoomView | null) {
    if (!voice.get().joined) return;
    if (!room) return this.leave();
    const me = room.members.find((m) => m.id === room.you);
    if (!me) return;
    if (!me.inVoice) {
      // Our socket reconnected and the server forgot us: everyone else dropped
      // our connection, so start over.
      if (this.serverKnowsUs) {
        this.serverKnowsUs = false;
        for (const p of this.peers.values()) p.close();
        this.peers.clear();
        net.voiceJoin();
        net.voiceMic(voice.get().micOn);
      }
      return;
    }
    this.serverKnowsUs = true;
    const wanted = new Set(room.members.filter((m) => m.inVoice && m.id !== room.you && !m.profile.bot).map((m) => m.id));
    for (const [id, p] of this.peers) {
      if (!wanted.has(id)) {
        p.close();
        this.peers.delete(id);
      }
    }
    for (const id of wanted) if (!this.peers.has(id)) this.open(id, room.you);
  }

  private startMeter() {
    if (this.meterTimer) return;
    this.meterTimer = window.setInterval(() => {
      const room = app.get().room;
      if (!room) return;
      const levels: Record<string, number> = {};
      if (this.localAnalyser && voice.get().micOn) levels[room.you] = rms(this.localAnalyser);
      for (const [id, p] of this.peers) levels[id] = p.level();
      const prev = voice.get().speaking;
      const next: Record<string, boolean> = {};
      let changed = false;
      for (const [id, level] of Object.entries(levels)) {
        const s = (this.smoothed[id] = (this.smoothed[id] ?? 0) * 0.6 + level * 0.4);
        const on = prev[id] ? s > 0.02 : s > 0.035;
        if (on) next[id] = true;
        if (!!prev[id] !== on) changed = true;
      }
      for (const id of Object.keys(prev)) if (!(id in levels)) changed = true;
      if (changed) voice.set({ speaking: next });
    }, 120);
  }
}

export const mesh = new Mesh();
