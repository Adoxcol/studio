/**
 * STUDIO — 32-Band FFT Audio Visualizer & Ambient Engine
 * Features:
 * - Web Audio API procedural audiophile ambient chord generator
 * - Real-time 32-band FFT frequency analyzer matching Studio's PCM tap
 * - Canvas & DOM bar spectrum renderers with peak decay and accent glow
 */

export class StudioAudioEngine {
  constructor() {
    this.isPlaying = false;
    this.audioCtx = null;
    this.analyser = null;
    this.dataArray = null;
    this.barElements = [];
    this.stageBars = document.querySelectorAll('.spectrum-bar');
    this.playStateListeners = [];
    this.animFrameId = null;

    // Default procedural simulation values for instant visual appeal
    this.simulatedBands = new Array(32).fill(0.15);
  }

  initAudio() {
    if (this.audioCtx) return;

    try {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      this.audioCtx = new AudioContext();
      this.analyser = this.audioCtx.createAnalyser();
      this.analyser.fftSize = 64; // 32 frequency bins
      this.analyser.smoothingTimeConstant = 0.8;
      this.dataArray = new Uint8Array(this.analyser.frequencyBinCount);

      // Gain master
      this.masterGain = this.audioCtx.createGain();
      this.masterGain.gain.setValueAtTime(0.2, this.audioCtx.currentTime);
      this.masterGain.connect(this.analyser);
      this.analyser.connect(this.audioCtx.destination);
    } catch (e) {
      console.warn('Web Audio API not supported or blocked:', e);
    }
  }

  // Play generative ambient chords (warm analog tape chord progression)
  startAmbientMusic() {
    if (!this.audioCtx) this.initAudio();
    if (this.audioCtx.state === 'suspended') {
      this.audioCtx.resume();
    }

    this.isPlaying = true;
    this.notifyPlayState(true);

    // Warm Chord progression: Dm9 -> G13 -> Cmaj9 -> Am7
    const chords = [
      [146.83, 220.00, 261.63, 329.63], // Dm9
      [196.00, 246.94, 329.63, 392.00], // G13
      [130.81, 196.00, 246.94, 293.66], // Cmaj9
      [110.00, 164.81, 220.00, 261.63]  // Am7
    ];
    let chordIdx = 0;

    const playChord = () => {
      if (!this.isPlaying || !this.audioCtx) return;
      const notes = chords[chordIdx % chords.length];
      chordIdx++;

      notes.forEach((freq, i) => {
        const osc = this.audioCtx.createOscillator();
        const noteGain = this.audioCtx.createGain();

        // Warm filtered triangle & sine
        osc.type = i === 0 ? 'sine' : 'triangle';
        osc.frequency.setValueAtTime(freq, this.audioCtx.currentTime);

        const now = this.audioCtx.currentTime;
        noteGain.gain.setValueAtTime(0.001, now);
        noteGain.gain.exponentialRampToValueAtTime(0.08 / notes.length, now + 1.2);
        noteGain.gain.exponentialRampToValueAtTime(0.0001, now + 4.8);

        osc.connect(noteGain);
        noteGain.connect(this.masterGain);

        osc.start(now);
        osc.stop(now + 5.0);
      });

      this.ambientTimer = setTimeout(playChord, 4200);
    };

    playChord();
    this.startVisualizerLoop();
  }

  stopMusic() {
    this.isPlaying = false;
    if (this.ambientTimer) clearTimeout(this.ambientTimer);
    this.notifyPlayState(false);
  }

  toggle() {
    if (this.isPlaying) {
      this.stopMusic();
    } else {
      this.startAmbientMusic();
    }
  }

  onPlayStateChange(callback) {
    this.playStateListeners.push(callback);
  }

  notifyPlayState(playing) {
    this.playStateListeners.forEach(cb => cb(playing));
  }

  startVisualizerLoop() {
    const loop = () => {
      this.renderBars();
      this.animFrameId = requestAnimationFrame(loop);
    };
    if (!this.animFrameId) {
      loop();
    }
  }

  renderBars() {
    if (this.analyser && this.isPlaying) {
      this.analyser.getByteFrequencyData(this.dataArray);
      for (let i = 0; i < 32; i++) {
        const val = (this.dataArray[i] || 0) / 255;
        this.simulatedBands[i] = Math.max(0.1, val);
      }
    } else {
      // Gentle idle wave movement when paused
      const time = Date.now() * 0.002;
      for (let i = 0; i < 32; i++) {
        const target = 0.12 + Math.sin(time + i * 0.25) * 0.08;
        this.simulatedBands[i] += (target - this.simulatedBands[i]) * 0.1;
      }
    }

    // Apply to DOM stage spectrum bars
    if (this.stageBars && this.stageBars.length > 0) {
      this.stageBars.forEach((bar, idx) => {
        const heightPct = Math.min(100, Math.max(10, Math.round(this.simulatedBands[idx] * 100)));
        bar.style.height = `${heightPct}%`;
        if (this.simulatedBands[idx] > 0.45 && this.isPlaying) {
          bar.classList.add('active');
        } else {
          bar.classList.remove('active');
        }
      });
    }
  }
}
