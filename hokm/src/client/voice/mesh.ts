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
//
// Phones are hard on long calls, so a watchdog keeps every connection
// honest: it brings back a microphone the phone took away (iOS does that
// whenever Safari goes to the background), restarts audio the phone paused,
// and repairs connections that dropped or stopped carrying sound.

/** How each connection is doing, for the mic badges at the table. */
export type Link = 'ok' | 'trying';

export interface VoiceState {
  joined: boolean;
  /** We hold a microphone track (it can still be switched off). */
  hasMic: boolean;
  micOn: boolean;
  speaking: Record<string, boolean>;
  muted: Record<string, boolean>;
  /** The browser blocked playback until the next tap. */
  needsTap: boolean;
  /** The phone took the microphone away and wants a tap before giving it back. */
  micLost: boolean;
  links: Record<string, Link>;
}

export const voice = createStore<VoiceState>({
  joined: false,
  hasMic: false,
  micOn: false,
  speaking: {},
  muted: {},
  needsTap: false,
  micLost: false,
  links: {},
});

export function useVoice<U>(selector: (s: VoiceState) => U): U {
  return useStore(voice, selector);
}

const MIC_CONSTRAINTS: MediaStreamConstraints = { audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true } };

/** Watchdog timings (ms). */
const W = {
  tick: 2500,
  /** A connection still not up after this long is rebuilt. */
  setup: 12_000,
  /** Disconnected this long: try fresh routes. */
  disconnectedRestart: 4000,
  /** Connected but no sound arriving from someone whose mic is on: try fresh routes, then rebuild. */
  silentRestart: 8000,
  silentRebuild: 18_000,
  restartGap: 6000,
  /** A mic muted by the phone this long is treated as gone. */
  micMuted: 3000,
  /** Gap between attempts to get the mic back without a tap. */
  micRetry: 8000,
} as const;

/**
 * Every connection carries a generation number. If one stalls, the side that
 * doesn't yield in negotiation rebuilds it with the next number, and the other
 * side rebuilds its end as soon as it sees that number.
 */
type Signal = { gen?: number; description?: RTCSessionDescriptionInit; candidate?: RTCIceCandidateInit };

class Peer {
  readonly pc: RTCPeerConnection;
  readonly audio: HTMLAudioElement;
  private sender: RTCRtpSender | null = null;
  private makingOffer = false;
  private ignoreOffer = false;
  private pendingCandidates: RTCIceCandidateInit[] = [];
  private stream: MediaStream | null = null;
  private closed = false;
  /** Last time this connection was known to be working (or was created). */
  lastGood = Date.now();
  private disconnectedAt = 0;
  private restartedAt = 0;
  private packets = -1;
  private silentSince = 0;
  /** What the badge at the table shows for this person. */
  health: Link = 'trying';

  constructor(
    readonly id: string,
    readonly polite: boolean,
    readonly gen: number,
    local: MediaStream | null,
    iceServers: RTCIceServer[],
    mesh: Mesh,
  ) {
    this.pc = new RTCPeerConnection({ iceServers });
    const track = local?.getAudioTracks()[0];
    if (track && local) this.sender = this.pc.addTrack(track, local);
    else this.pc.addTransceiver('audio', { direction: 'recvonly' });

    this.audio = document.createElement('audio');
    this.audio.autoplay = true;
    this.audio.setAttribute('playsinline', '');
    this.audio.muted = !!voice.get().muted[id];
    // A phone can pause playback on its own (an interruption, the app coming back): start it again.
    this.audio.addEventListener('pause', () => window.setTimeout(() => this.resume(), 300));
    mesh.audioHost().appendChild(this.audio);

    this.pc.onnegotiationneeded = () => void this.offer();
    this.pc.onicecandidate = ({ candidate }) => {
      if (candidate) this.send({ candidate: candidate.toJSON() });
    };
    // The remote stream goes straight to an <audio> element and nowhere else: feeding it
    // into Web Audio as well can silence it on iPhones. Speaking levels come from RTP instead.
    this.pc.ontrack = (e) => {
      const stream = e.streams[0] ?? new MediaStream([e.track]);
      this.stream = stream;
      this.audio.srcObject = stream;
      this.play();
    };
    this.pc.onconnectionstatechange = () => {
      const state = this.pc.connectionState;
      if (state === 'connected') {
        this.lastGood = Date.now();
        this.disconnectedAt = 0;
        this.health = 'ok';
        this.resume();
      } else if (state === 'disconnected') {
        this.disconnectedAt ||= Date.now();
      } else if (state === 'failed') {
        this.restart();
      }
      if (state !== 'connected') this.health = 'trying';
      mesh.refreshLinks();
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

  /** Looks for a fresh network path without tearing the connection down. */
  restart() {
    if (this.closed || Date.now() - this.restartedAt < W.restartGap) return;
    this.restartedAt = Date.now();
    this.pc.restartIce?.();
  }

  /** Puts a new microphone track on the connection, without renegotiating when it can. */
  async useTrack(track: MediaStreamTrack, stream: MediaStream) {
    if (this.closed) return;
    try {
      if (this.sender) await this.sender.replaceTrack(track);
      else this.sender = this.pc.addTrack(track, stream);
    } catch (err) {
      console.warn('voice track swap failed', err);
    }
  }

  /**
   * Checks the connection and says what it needs. `remoteMicOn` is whether
   * the other side says its mic is on: only then should sound be arriving.
   */
  async check(remoteMicOn: boolean): Promise<'ok' | 'trying' | 'rebuild'> {
    const verdict = await this.diagnose(remoteMicOn);
    this.health = verdict === 'ok' ? 'ok' : 'trying';
    return verdict;
  }

  private async diagnose(remoteMicOn: boolean): Promise<'ok' | 'trying' | 'rebuild'> {
    if (this.closed) return 'ok';
    const now = Date.now();
    const state = this.pc.connectionState;
    if (this.stream && this.audio.paused) this.resume();
    if (state === 'connected') {
      const packets = await this.packetsReceived();
      const flowing = packets > this.packets;
      this.packets = Math.max(this.packets, packets);
      if (!remoteMicOn || flowing) {
        this.silentSince = 0;
        this.lastGood = now;
        return 'ok';
      }
      // Connected, their mic is on, yet nothing arrives: the path died quietly.
      this.silentSince ||= now;
      const silent = now - this.silentSince;
      if (silent > W.silentRebuild) return 'rebuild';
      if (silent > W.silentRestart) this.restart();
      return silent > W.silentRestart ? 'trying' : 'ok';
    }
    if (state === 'disconnected' && this.disconnectedAt && now - this.disconnectedAt > W.disconnectedRestart) this.restart();
    return now - this.lastGood > W.setup ? 'rebuild' : 'trying';
  }

  private async packetsReceived(): Promise<number> {
    try {
      const stats = await this.pc.getStats();
      let total = 0;
      stats.forEach((s) => {
        if (s.type === 'inbound-rtp' && (s.kind === 'audio' || s.mediaType === 'audio')) total += s.packetsReceived ?? 0;
      });
      return total;
    } catch {
      return this.packets;
    }
  }

  play() {
    if (this.closed) return;
    this.audio.play().then(
      () => voice.set({ needsTap: false }),
      () => voice.set({ needsTap: true }),
    );
  }

  /** Starts playback again if the phone paused it. */
  resume() {
    if (!this.closed && this.stream && this.audio.paused) this.play();
  }

  /** How loud the other side is right now (0–1), from the RTP audio level headers. */
  level(): number {
    if (!this.stream) return 0;
    try {
      const receiver = this.pc.getReceivers().find((r) => r.track?.kind === 'audio');
      const src = receiver?.getSynchronizationSources?.()[0];
      if (!src) return 0;
      // A level that hasn't been refreshed lately is a stale reading of someone who went quiet.
      const age = Math.min(Math.abs(performance.now() - src.timestamp), Math.abs(Date.now() - src.timestamp));
      return age > 800 ? 0 : (src.audioLevel ?? 0);
    } catch {
      return 0;
    }
  }

  get hasStream() {
    return !!this.stream;
  }

  close() {
    this.closed = true;
    this.pc.onconnectionstatechange = null;
    this.pc.onnegotiationneeded = null;
    this.pc.ontrack = null;
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
  /** We had a microphone when we joined, so losing it is something to fix. */
  private wantsMic = false;
  private recovering = false;
  private lastRecoverAt = 0;
  private mutedSince = 0;
  private checking = false;

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
    window.setInterval(() => void this.watch(), W.tick);
    app.subscribe(() => this.sync(app.get().room));

    // Any tap is a chance to resume what the browser blocked: playback, or a microphone it took away.
    const onTap = () => {
      if (!voice.get().joined) return;
      for (const p of this.peers.values()) p.resume();
      if (voice.get().needsTap) for (const p of this.peers.values()) p.play();
      if (voice.get().micLost) void this.recoverMic(true);
    };
    for (const type of ['pointerup', 'touchend', 'keydown']) window.addEventListener(type, onTap, { passive: true });

    // Coming back to the page (after sharing the link, a call, the screen locking) is when
    // phones have paused audio and taken the microphone; put both back.
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState !== 'visible' || !voice.get().joined) return;
      for (const p of this.peers.values()) p.resume();
      window.setTimeout(() => void this.recoverMic(false), 700);
      void this.watch();
    });
    navigator.mediaDevices?.addEventListener?.('devicechange', () => {
      if (voice.get().joined) window.setTimeout(() => void this.recoverMic(false), 500);
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

  /** A level meter for our own microphone. (Other people's levels come from RTP.) */
  private analyse(stream: MediaStream): AnalyserNode | null {
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
      this.setLocal(await navigator.mediaDevices.getUserMedia(MIC_CONSTRAINTS));
    } catch {
      this.setLocal(null);
      toast(t('mic_blocked'), 'bad', 4000);
    }
    this.wantsMic = !!this.local;
    const micOn = !!this.local && settings.get().voiceMode === 'open';
    this.local?.getAudioTracks().forEach((tr) => (tr.enabled = micOn));
    voice.set({ joined: true, hasMic: !!this.local, micOn, micLost: false, links: {} });
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
    this.setLocal(null);
    this.wantsMic = false;
    if (this.meterTimer) clearInterval(this.meterTimer);
    this.meterTimer = null;
    voice.set({ joined: false, hasMic: false, micOn: false, speaking: {}, needsTap: false, micLost: false, links: {} });
    net.voiceLeave();
  }

  /** Starts every connection afresh: the "it's not working" button. */
  reconnect() {
    const room = app.get().room;
    if (!voice.get().joined || !room) return;
    for (const [id, p] of [...this.peers]) {
      p.close();
      this.open(id, room.you, p.gen + 1);
    }
    void this.recoverMic(true);
    this.refreshLinks();
    sfx.play('chime');
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
  debug(): Record<string, { gen: number; connection: RTCPeerConnectionState; ice: RTCIceConnectionState; receiving: boolean; playing: boolean }> {
    const out: Record<string, { gen: number; connection: RTCPeerConnectionState; ice: RTCIceConnectionState; receiving: boolean; playing: boolean }> = {};
    for (const [id, p] of this.peers) {
      out[id] = { gen: p.gen, connection: p.pc.connectionState, ice: p.pc.iceConnectionState, receiving: p.hasStream, playing: !p.audio.paused };
    }
    return out;
  }

  private setLocal(stream: MediaStream | null) {
    this.local = stream;
    this.localAnalyser = stream ? this.analyse(stream) : null;
    const track = stream?.getAudioTracks()[0];
    // The phone ending our capture (a call, Siri, another app) is how a mic goes dead mid-game.
    if (track) track.addEventListener('ended', () => window.setTimeout(() => void this.recoverMic(false), 300));
  }

  /** Whether our microphone track has been taken away, or frozen for a while. */
  private micDead(): boolean {
    const track = this.local?.getAudioTracks()[0];
    if (!track || track.readyState === 'ended') return true;
    if (!track.muted) {
      this.mutedSince = 0;
      return false;
    }
    this.mutedSince ||= Date.now();
    return Date.now() - this.mutedSince > W.micMuted;
  }

  /**
   * Gets the microphone back after the phone took it, and swaps the new
   * track into every connection. Some phones only allow that from a tap;
   * then we ask for one.
   */
  private async recoverMic(fromTap: boolean) {
    if (!voice.get().joined || !this.wantsMic || this.recovering || !this.micDead()) return;
    if (!fromTap && (document.visibilityState !== 'visible' || Date.now() - this.lastRecoverAt < W.micRetry)) return;
    this.recovering = true;
    this.lastRecoverAt = Date.now();
    try {
      const fresh = await navigator.mediaDevices.getUserMedia(MIC_CONSTRAINTS);
      const track = fresh.getAudioTracks()[0];
      if (!track || !voice.get().joined) {
        fresh.getTracks().forEach((tr) => tr.stop());
        return;
      }
      track.enabled = voice.get().micOn;
      this.local?.getTracks().forEach((tr) => tr.stop());
      this.mutedSince = 0;
      this.setLocal(fresh);
      for (const p of this.peers.values()) await p.useTrack(track, fresh);
      const wasLost = voice.get().micLost;
      voice.set({ hasMic: true, micLost: false });
      if (wasLost) toast(t('mic_back'), 'good', 1800);
    } catch {
      if (!voice.get().micLost) toast(t('mic_lost'), 'info', 3500);
      voice.set({ micLost: true });
    } finally {
      this.recovering = false;
    }
  }

  private open(id: string, me: string, gen = 0): Peer {
    const peer = new Peer(id, me > id, gen, this.local, app.get().iceServers as RTCIceServer[], this);
    this.peers.set(id, peer);
    return peer;
  }

  /** The watchdog: keeps audio playing, the mic alive and every connection carrying sound. */
  private async watch() {
    const room = app.get().room;
    if (!voice.get().joined || !room || this.checking) return;
    this.checking = true;
    try {
      if (this.micDead() && this.wantsMic) void this.recoverMic(false);
      for (const [id, p] of [...this.peers]) {
        const member = room.members.find((m) => m.id === id);
        const verdict = await p.check(!!member?.micOn);
        // Only the side that doesn't yield in negotiation rebuilds, so the two ends don't race.
        if (verdict === 'rebuild' && !p.polite && this.peers.get(id) === p) {
          p.close();
          this.open(id, room.you, p.gen + 1);
        }
      }
    } finally {
      this.checking = false;
      this.refreshLinks();
    }
  }

  /** Publishes which connections work, for the badges at the table. */
  refreshLinks() {
    const links: Record<string, Link> = {};
    for (const [id, p] of this.peers) links[id] = p.health;
    const prev = voice.get().links;
    const same = Object.keys(links).length === Object.keys(prev).length && Object.entries(links).every(([k, v]) => prev[k] === v);
    if (!same) voice.set({ links });
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
    let changed = false;
    for (const [id, p] of this.peers) {
      if (!wanted.has(id)) {
        p.close();
        this.peers.delete(id);
        changed = true;
      }
    }
    for (const id of wanted) {
      if (!this.peers.has(id)) {
        this.open(id, room.you);
        changed = true;
      }
    }
    if (changed) this.refreshLinks();
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
