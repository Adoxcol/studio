/**
 * STUDIO — Main Orchestrator
 * Connects 3D Vinyl, Audio Engine, Equalizer, Docking Demo, Themes & Dynamic OKLCH Color
 */

import { StudioVinylStage } from './three-vinyl.js';
import { StudioAudioEngine } from './audio-visualizer.js';
import { StudioEqualizer } from './equalizer.js';
import { StudioDockingDemo } from './docking-demo.js';

class StudioApp {
  constructor() {
    this.initTheme();
    this.initAccentEngine();
    this.initComponents();
    this.initPlayerControls();
    this.initSpotlightTour();
    this.detectPlatform();
  }

  initTheme() {
    const savedTheme = localStorage.getItem('studio-theme') || 'dark';
    document.documentElement.setAttribute('data-theme', savedTheme);

    const themeToggleBtn = document.getElementById('theme-toggle-btn');
    if (themeToggleBtn) {
      themeToggleBtn.addEventListener('click', () => {
        const current = document.documentElement.getAttribute('data-theme');
        const next = current === 'dark' ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', next);
        localStorage.setItem('studio-theme', next);

        // Update EQ curve with new theme colors
        if (this.equalizer) {
          setTimeout(() => this.equalizer.renderCurve(), 50);
        }
      });
    }
  }

  initAccentEngine() {
    const hueSlider = document.getElementById('accent-hue-slider');
    const hueValueLabel = document.getElementById('hue-value-label');
    const swatches = document.querySelectorAll('.swatch-btn');

    const updateHue = (hue) => {
      document.documentElement.style.setProperty('--accent-hue', hue);
      if (hueValueLabel) hueValueLabel.textContent = `${hue}°`;

      // Convert HSL to Hex for Three.js 3D light
      const hexColor = this.hslToHex(hue, 80, 58);
      if (this.vinylStage) {
        this.vinylStage.setAccentColor(hexColor);
      }
      if (this.equalizer) {
        this.equalizer.renderCurve();
      }
    };

    if (hueSlider) {
      hueSlider.addEventListener('input', (e) => {
        swatches.forEach(s => s.classList.remove('active'));
        updateHue(e.target.value);
      });
    }

    swatches.forEach(btn => {
      btn.addEventListener('click', () => {
        swatches.forEach(s => s.classList.remove('active'));
        btn.classList.add('active');
        const hue = btn.dataset.hue;
        if (hueSlider) hueSlider.value = hue;
        updateHue(hue);
      });
    });
  }

  hslToHex(h, s, l) {
    l /= 100;
    const a = s * Math.min(l, 1 - l) / 100;
    const f = n => {
      const k = (n + h / 30) % 12;
      const color = l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
      return Math.round(255 * color).toString(16).padStart(2, '0');
    };
    return `#${f(0)}${f(8)}${f(4)}`;
  }

  initComponents() {
    // 3D Vinyl WebGL
    this.vinylStage = new StudioVinylStage('vinyl-canvas-container');

    // Web Audio Engine & 32-band FFT
    this.audioEngine = new StudioAudioEngine();

    // ISO 10-Band Graphic Equalizer
    this.equalizer = new StudioEqualizer('eq-curve-canvas');

    // Docking Layout Demo
    this.dockingDemo = new StudioDockingDemo();
  }

  initPlayerControls() {
    const playButtons = document.querySelectorAll('.play-trigger-btn');
    const playIcons = document.querySelectorAll('.play-icon-symbol');

    const updatePlayUI = (isPlaying) => {
      playIcons.forEach(icon => {
        // SVG paths or symbols
        if (isPlaying) {
          icon.innerHTML = '<rect x="6" y="4" width="4" height="16" fill="currentColor"/><rect x="14" y="4" width="4" height="16" fill="currentColor"/>';
        } else {
          icon.innerHTML = '<polygon points="5 3 19 12 5 21 5 3" fill="currentColor"/>';
        }
      });
      if (this.vinylStage) {
        this.vinylStage.togglePlay(isPlaying);
      }
    };

    playButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        this.audioEngine.toggle();
      });
    });

    this.audioEngine.onPlayStateChange((isPlaying) => {
      updatePlayUI(isPlaying);
    });
  }

  initSpotlightTour() {
    const tabs = document.querySelectorAll('.spotlight-tab');
    const mainImg = document.getElementById('spotlight-main-img');
    const titleLabel = document.getElementById('spotlight-title-label');
    const heading = document.getElementById('spotlight-heading');
    const paragraph = document.getElementById('spotlight-paragraph');
    const bulletsContainer = document.getElementById('spotlight-bullets-container');

    if (!tabs || tabs.length === 0 || !mainImg) return;

    // Preload all spotlight images into cache immediately
    tabs.forEach(tab => {
      const src = tab.dataset.img;
      if (src) {
        const preloadImg = new Image();
        preloadImg.src = src;
      }
    });

    let currentTransitionId = 0;

    tabs.forEach(tab => {
      tab.addEventListener('click', () => {
        tabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');

        const imgSrc = tab.dataset.img;
        const title = tab.dataset.title;
        const desc = tab.dataset.desc;
        const bullets = (tab.dataset.bullets || '').split('|');

        if (titleLabel) titleLabel.textContent = `Studio — ${title}`;
        if (heading) heading.textContent = title;
        if (paragraph) paragraph.textContent = desc;

        if (bulletsContainer && bullets.length > 0) {
          bulletsContainer.innerHTML = bullets.map(b => `
            <div class="spotlight-bullet">
              <svg class="spotlight-bullet-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
              <span>${b}</span>
            </div>
          `).join('');
        }

        // Increment transition id to invalidate any prior in-flight loads
        const thisTransitionId = ++currentTransitionId;

        // Smooth image swap with cache check and onload handling
        mainImg.style.opacity = '0.3';

        const tempImg = new Image();
        tempImg.onload = () => {
          if (thisTransitionId !== currentTransitionId) return;
          mainImg.src = imgSrc;
          mainImg.style.opacity = '1';
        };
        tempImg.onerror = () => {
          if (thisTransitionId !== currentTransitionId) return;
          // Fallback: still set src and restore opacity so browser handles or retry
          mainImg.src = imgSrc;
          mainImg.style.opacity = '1';
        };
        tempImg.src = imgSrc;

        // In case image is already cached and loaded synchronously
        if (tempImg.complete && tempImg.naturalWidth > 0) {
          mainImg.src = imgSrc;
          mainImg.style.opacity = '1';
        }
      });
    });
  }

  detectPlatform() {
    const userAgent = window.navigator.userAgent.toLowerCase();
    const heroDownloadBtn = document.getElementById('hero-download-btn');
    const heroPlatformLabel = document.getElementById('hero-platform-label');

    let os = 'Windows';
    let file = 'studio-windows-x64.zip';

    if (userAgent.includes('mac')) {
      os = 'macOS';
      file = 'studio-macos.zip';
    } else if (userAgent.includes('linux')) {
      os = 'Linux';
      file = 'studio-linux-x64.tar.gz';
    }

    if (heroDownloadBtn && heroPlatformLabel) {
      heroPlatformLabel.textContent = `Download for ${os}`;
      heroDownloadBtn.href = `https://github.com/Adoxcol/studio/releases/latest/download/${file}`;
    }
  }
}

// Bootstrap when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  window.studioApp = new StudioApp();
});
