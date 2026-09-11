/**
 * STUDIO — ISO 10-Band Graphic Equalizer
 * Features:
 * - 10 Standard ISO frequencies (31 Hz - 16 kHz) with +/- 12 dB fader range
 * - Real-time canvas cubic spline frequency response curve drawing with dynamic accent fill
 * - Factory presets (Flat, Bass Boost, Vocal Warmth, Acoustic Air, Electronic)
 */

export class StudioEqualizer {
  constructor(canvasId) {
    this.canvas = document.getElementById(canvasId);
    this.bands = [
      { freq: '31 Hz', gain: 0 },
      { freq: '63 Hz', gain: 0 },
      { freq: '125 Hz', gain: 0 },
      { freq: '250 Hz', gain: 0 },
      { freq: '500 Hz', gain: 0 },
      { freq: '1 kHz', gain: 0 },
      { freq: '2 kHz', gain: 0 },
      { freq: '4 kHz', gain: 0 },
      { freq: '8 kHz', gain: 0 },
      { freq: '16 kHz', gain: 0 }
    ];

    this.presets = {
      flat: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      bass: [5.5, 4.8, 3.2, 1.5, 0, 0, 0.8, 2.0, 3.5, 4.0],
      vocal: [-1.5, -0.5, 1.2, 3.0, 4.2, 3.5, 2.0, 0.5, -1.0, -2.0],
      acoustic: [1.2, 1.8, 0.5, -0.5, 1.0, 2.5, 3.8, 4.5, 5.0, 4.2],
      electronic: [6.5, 5.2, 3.0, -1.0, -1.5, 1.2, 2.8, 4.5, 6.0, 6.2]
    };

    if (this.canvas) {
      this.ctx = this.canvas.getContext('2d');
      this.init();
    }
  }

  init() {
    this.setupResize();
    this.renderCurve();
    this.bindEvents();
  }

  setupResize() {
    const resize = () => {
      if (!this.canvas) return;
      const rect = this.canvas.parentElement.getBoundingClientRect();
      this.canvas.width = rect.width * (window.devicePixelRatio || 1);
      this.canvas.height = rect.height * (window.devicePixelRatio || 1);
      this.ctx.scale(window.devicePixelRatio || 1, window.devicePixelRatio || 1);
      this.width = rect.width;
      this.height = rect.height;
      this.renderCurve();
    };

    window.addEventListener('resize', resize);
    resize();
  }

  bindEvents() {
    // Preset buttons
    const presetButtons = document.querySelectorAll('.eq-preset-btn');
    presetButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        const presetName = btn.dataset.preset;
        if (this.presets[presetName]) {
          presetButtons.forEach(b => b.classList.remove('active'));
          btn.classList.add('active');
          this.applyPreset(this.presets[presetName]);
        }
      });
    });

    // Faders
    const sliders = document.querySelectorAll('.eq-fader');
    sliders.forEach((slider, idx) => {
      slider.addEventListener('input', (e) => {
        const val = parseFloat(e.target.value);
        this.bands[idx].gain = val;
        const gainLabel = slider.closest('.eq-band').querySelector('.eq-gain-label');
        if (gainLabel) {
          gainLabel.textContent = (val > 0 ? `+${val.toFixed(1)}` : val.toFixed(1)) + ' dB';
        }
        this.renderCurve();
      });
    });
  }

  applyPreset(values) {
    values.forEach((gain, idx) => {
      this.bands[idx].gain = gain;
      const slider = document.querySelector(`.eq-fader[data-index="${idx}"]`);
      if (slider) {
        slider.value = gain;
        const gainLabel = slider.closest('.eq-band').querySelector('.eq-gain-label');
        if (gainLabel) {
          gainLabel.textContent = (gain > 0 ? `+${gain.toFixed(1)}` : gain.toFixed(1)) + ' dB';
        }
      }
    });
    this.renderCurve();
  }

  renderCurve() {
    if (!this.ctx || !this.width) return;

    const ctx = this.ctx;
    const w = this.width;
    const h = this.height;

    ctx.clearRect(0, 0, w, h);

    // Grid lines (dB levels: +12, +6, 0, -6, -12)
    const midY = h / 2;
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)';
    ctx.lineWidth = 1;

    [-12, -6, 0, 6, 12].forEach(db => {
      const y = midY - (db / 12) * (midY - 14);
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    });

    // 0 dB center reference line
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.12)';
    ctx.beginPath();
    ctx.moveTo(0, midY);
    ctx.lineTo(w, midY);
    ctx.stroke();

    // Calculate curve points
    const points = [];
    const step = w / (this.bands.length - 1);

    this.bands.forEach((band, i) => {
      const x = i * step;
      // map -12 dB .. +12 dB to height
      const y = midY - (band.gain / 12) * (midY - 16);
      points.push({ x, y });
    });

    // Draw Smooth Spline
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);

    for (let i = 0; i < points.length - 1; i++) {
      const xc = (points[i].x + points[i + 1].x) / 2;
      const yc = (points[i].y + points[i + 1].y) / 2;
      ctx.quadraticCurveTo(points[i].x, points[i].y, xc, yc);
    }
    ctx.lineTo(points[points.length - 1].x, points[points.length - 1].y);

    // Stroke line
    ctx.strokeStyle = getComputedStyle(document.documentElement).getPropertyValue('--accent') || '#E28A36';
    ctx.lineWidth = 2.5;
    ctx.shadowColor = ctx.strokeStyle;
    ctx.shadowBlur = 12;
    ctx.stroke();

    // Fill underneath curve
    ctx.shadowBlur = 0;
    ctx.lineTo(w, midY);
    ctx.lineTo(0, midY);
    ctx.closePath();

    const grad = ctx.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, 'rgba(226, 138, 54, 0.18)');
    grad.addColorStop(1, 'rgba(226, 138, 54, 0.01)');
    ctx.fillStyle = grad;
    ctx.fill();

    // Control Nodes
    points.forEach(p => {
      ctx.beginPath();
      ctx.arc(p.x, p.y, 3.5, 0, Math.PI * 2);
      ctx.fillStyle = '#FFFFFF';
      ctx.fill();
    });
  }
}
