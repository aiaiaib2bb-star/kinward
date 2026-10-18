import { settings } from '../state/settings';

// Every sound in the game is synthesised on the spot with Web Audio: card
// flicks are filtered noise, the slam is a falling sine with a crack on
// top, the riffle is a run of tiny clicks that speeds up. No audio files to
// download or license.

export type Sound =
  | 'card'
  | 'flick'
  | 'deal'
  | 'slam'
  | 'riffle'
  | 'cut'
  | 'turn'
  | 'tick'
  | 'trickWin'
  | 'trickLose'
  | 'kot'
  | 'coin'
  | 'win'
  | 'lose'
  | 'pop'
  | 'splat'
  | 'bonk'
  | 'boom'
  | 'chime'
  | 'kiss'
  | 'error'
  | 'click'
  | 'whoosh'
  | 'stamp'
  | 'thunder'
  | 'fire'
  | 'confetti'
  | 'quake'
  | 'select';

interface ToneOpts {
  type?: OscillatorType;
  gain?: number;
  to?: number;
  attack?: number;
}

interface NoiseOpts {
  gain?: number;
  filter?: BiquadFilterType;
  freq?: number;
  to?: number;
  q?: number;
}

class Sfx {
  private ctx: AudioContext | null = null;
  private out: GainNode | null = null;
  private noise: AudioBuffer | null = null;
  private primed = false;

  private ensure(): AudioContext | null {
    if (!this.ctx) {
      const AC = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!AC) return null;
      const ctx = new AC({ latencyHint: 'interactive' });
      const out = ctx.createGain();
      const comp = ctx.createDynamicsCompressor();
      comp.threshold.value = -10;
      comp.ratio.value = 6;
      out.connect(comp).connect(ctx.destination);
      const buffer = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
      const data = buffer.getChannelData(0);
      for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
      this.ctx = ctx;
      this.out = out;
      this.noise = buffer;
    }
    if (this.ctx.state === 'suspended') void this.ctx.resume();
    return this.ctx;
  }

  /** Browsers only allow audio after a tap; call this from taps until it's running. */
  unlock() {
    if (this.primed && this.ctx?.state === 'running') return;
    const ctx = this.ensure();
    if (!ctx) return;
    // iOS wants a sound started inside the gesture itself; a silent one will do.
    const src = ctx.createBufferSource();
    src.buffer = ctx.createBuffer(1, 1, 22050);
    src.connect(ctx.destination);
    src.start(0);
    if (ctx.state === 'running') this.primed = true;
  }

  get context(): AudioContext | null {
    return this.ensure();
  }

  private tone(freq: number, at: number, dur: number, o: ToneOpts = {}) {
    const ctx = this.ctx!;
    const t0 = ctx.currentTime + at;
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = o.type ?? 'sine';
    osc.frequency.setValueAtTime(freq, t0);
    if (o.to) osc.frequency.exponentialRampToValueAtTime(Math.max(1, o.to), t0 + dur);
    const peak = o.gain ?? 0.2;
    const attack = o.attack ?? 0.005;
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(peak, t0 + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(g).connect(this.out!);
    osc.start(t0);
    osc.stop(t0 + dur + 0.02);
  }

  private hiss(at: number, dur: number, o: NoiseOpts = {}) {
    const ctx = this.ctx!;
    const t0 = ctx.currentTime + at;
    const src = ctx.createBufferSource();
    src.buffer = this.noise;
    const filter = ctx.createBiquadFilter();
    filter.type = o.filter ?? 'bandpass';
    filter.frequency.setValueAtTime(o.freq ?? 2000, t0);
    if (o.to) filter.frequency.exponentialRampToValueAtTime(o.to, t0 + dur);
    filter.Q.value = o.q ?? 0.8;
    const g = ctx.createGain();
    g.gain.setValueAtTime(o.gain ?? 0.3, t0);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    src.connect(filter).connect(g).connect(this.out!);
    src.start(t0, Math.random() * 0.5);
    src.stop(t0 + dur + 0.02);
  }

  play(sound: Sound, power = 1) {
    const s = settings.get();
    if (!s.sound) return;
    const ctx = this.ensure();
    if (!ctx || !this.out) return;
    this.out.gain.value = s.volume;
    switch (sound) {
      case 'card':
        this.hiss(0, 0.05, { freq: 2600, gain: 0.45 });
        this.tone(170, 0, 0.07, { to: 90, gain: 0.3 });
        break;
      case 'select':
        this.hiss(0, 0.03, { freq: 4200, gain: 0.12, q: 2 });
        break;
      case 'flick':
        this.hiss(0, 0.13, { filter: 'highpass', freq: 1400, to: 5200, gain: 0.22 });
        break;
      case 'deal':
        this.hiss(0, 0.045, { freq: 3600, gain: 0.2, q: 1.4 });
        break;
      case 'slam': {
        const p = 0.45 + 0.55 * Math.max(0, Math.min(1, power));
        this.tone(120, 0, 0.5, { to: 36, gain: 0.95 * p });
        this.tone(58, 0, 0.7, { type: 'triangle', gain: 0.4 * p });
        this.hiss(0, 0.14, { filter: 'lowpass', freq: 2200, to: 300, gain: 0.75 * p });
        this.hiss(0, 0.03, { filter: 'highpass', freq: 3000, gain: 0.45 * p });
        break;
      }
      case 'riffle': {
        const n = 24;
        for (let i = 0; i < n; i++) {
          const at = 0.5 * Math.pow(i / n, 0.85);
          this.hiss(at, 0.014, { freq: 3800 + Math.random() * 1500, q: 2.2, gain: 0.12 + Math.random() * 0.1 });
        }
        this.tone(150, 0.56, 0.06, { to: 100, gain: 0.22 });
        this.hiss(0.56, 0.05, { freq: 1800, gain: 0.2 });
        break;
      }
      case 'cut':
        this.hiss(0, 0.06, { freq: 1900, gain: 0.3 });
        this.hiss(0.3, 0.07, { freq: 1500, gain: 0.32 });
        this.tone(130, 0.31, 0.08, { to: 85, gain: 0.3 });
        break;
      case 'turn':
        this.tone(659, 0, 0.22, { gain: 0.24, attack: 0.01 });
        this.tone(988, 0.12, 0.38, { gain: 0.22, attack: 0.01 });
        break;
      case 'tick':
        this.tone(1600, 0, 0.03, { type: 'square', gain: 0.04 });
        break;
      case 'trickWin':
        [523, 659, 784].forEach((f, i) => this.tone(f, i * 0.07, 0.16, { type: 'triangle', gain: 0.16 }));
        break;
      case 'trickLose':
        [392, 311].forEach((f, i) => this.tone(f, i * 0.1, 0.2, { type: 'triangle', gain: 0.12 }));
        break;
      case 'kot':
        this.tone(160, 0, 0.4, { to: 48, gain: 0.85 });
        this.hiss(0, 0.16, { filter: 'lowpass', freq: 1000, gain: 0.5 });
        [523, 659, 784, 1047].forEach((f, i) => this.tone(f, 0.12 + i * 0.09, 0.55, { type: 'triangle', gain: 0.14 }));
        break;
      case 'coin':
        this.tone(1976, 0, 0.09, { gain: 0.13 });
        this.tone(2637, 0.07, 0.3, { gain: 0.13 });
        break;
      case 'win':
        [523, 659, 784, 1047].forEach((f, i) => this.tone(f, i * 0.12, 0.3, { type: 'triangle', gain: 0.18 }));
        [523, 659, 784].forEach((f) => this.tone(f, 0.5, 0.9, { type: 'triangle', gain: 0.1, attack: 0.03 }));
        break;
      case 'lose':
        [392, 330, 262].forEach((f, i) => this.tone(f, i * 0.18, 0.35, { type: 'triangle', gain: 0.14 }));
        break;
      case 'pop':
        this.tone(480, 0, 0.09, { to: 950, gain: 0.2 });
        break;
      case 'splat':
        this.hiss(0, 0.24, { filter: 'lowpass', freq: 1000, to: 250, gain: 0.6 });
        this.tone(130, 0, 0.2, { to: 55, gain: 0.35 });
        break;
      case 'bonk':
        this.tone(820, 0, 0.05, { type: 'square', gain: 0.16 });
        this.tone(340, 0.02, 0.4, { to: 150, gain: 0.28 });
        break;
      case 'boom':
        this.hiss(0, 0.45, { filter: 'lowpass', freq: 3200, to: 180, gain: 0.85 });
        for (let i = 0; i < 9; i++) this.hiss(0.1 + Math.random() * 0.55, 0.02, { filter: 'highpass', freq: 2500, gain: 0.3 });
        break;
      case 'chime':
        this.tone(1319, 0, 0.7, { gain: 0.13, attack: 0.01 });
        this.tone(1976, 0.06, 0.6, { gain: 0.08, attack: 0.01 });
        break;
      case 'kiss':
        this.tone(900, 0, 0.13, { to: 1600, gain: 0.18 });
        this.hiss(0, 0.05, { filter: 'highpass', freq: 4500, gain: 0.08 });
        break;
      case 'error':
        this.tone(160, 0, 0.16, { type: 'square', gain: 0.08 });
        break;
      case 'click':
        this.tone(1250, 0, 0.025, { gain: 0.06 });
        break;
      case 'whoosh':
        this.hiss(0, 0.38, { freq: 700, to: 3200, q: 1.1, gain: 0.25 });
        break;
      case 'stamp':
        this.tone(95, 0, 0.25, { to: 55, gain: 0.7 });
        this.hiss(0, 0.08, { filter: 'lowpass', freq: 1300, gain: 0.4 });
        break;
      case 'thunder':
        this.hiss(0, 0.05, { filter: 'highpass', freq: 2200, gain: 0.55 });
        this.hiss(0.02, 1.0, { filter: 'lowpass', freq: 700, to: 110, gain: 0.85 });
        break;
      case 'fire':
        this.hiss(0, 0.7, { freq: 500, to: 1400, q: 0.5, gain: 0.45 });
        this.tone(90, 0, 0.4, { to: 45, gain: 0.5 });
        break;
      case 'confetti':
        this.tone(500, 0, 0.08, { to: 1100, gain: 0.2 });
        for (let i = 0; i < 6; i++) this.tone(1800 + Math.random() * 1600, 0.05 + i * 0.05, 0.05, { gain: 0.05 });
        break;
      case 'quake':
        this.tone(44, 0, 1.1, { gain: 0.9, attack: 0.02 });
        this.hiss(0, 1.1, { filter: 'lowpass', freq: 240, gain: 0.7 });
        this.hiss(0, 0.06, { filter: 'highpass', freq: 2000, gain: 0.4 });
        break;
    }
  }
}

export const sfx = new Sfx();

/** Which sound a thrown item makes when it lands. */
export const THROW_SOUND: Record<string, Sound> = {
  throw_rose: 'chime',
  throw_tomato: 'splat',
  throw_tea: 'chime',
  throw_egg: 'splat',
  throw_kiss: 'kiss',
  throw_melon: 'splat',
  throw_bouquet: 'chime',
  throw_slipper: 'bonk',
  throw_firecracker: 'boom',
};

export const SLAM_SOUND: Record<string, Sound> = {
  slam_thud: 'slam',
  slam_confetti: 'confetti',
  slam_lightning: 'thunder',
  slam_fire: 'fire',
  slam_quake: 'quake',
};
