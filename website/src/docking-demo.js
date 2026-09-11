/**
 * STUDIO — Modular Docking Layout Showcase
 * Features:
 * - Dynamic layout morphing simulating Flutter's `docking` package
 * - Preset modes: "Default Studio", "Lyrics Stage", "Audiophile Console", "Minimalist"
 * - Interactive synced lyrics click-to-seek
 */

export class StudioDockingDemo {
  constructor() {
    this.workspace = document.querySelector('.dock-workspace');
    this.tabButtons = document.querySelectorAll('.dock-tab-btn');
    this.lyricLines = document.querySelectorAll('.lyric-line');
    this.init();
  }

  init() {
    this.setupTabs();
    this.setupLyrics();
  }

  setupTabs() {
    if (!this.tabButtons || !this.workspace) return;

    this.tabButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        this.tabButtons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        const mode = btn.dataset.layout;
        this.applyLayout(mode);
      });
    });
  }

  applyLayout(mode) {
    if (!this.workspace) return;

    switch (mode) {
      case 'default':
        this.workspace.style.gridTemplateColumns = '260px 1fr 300px';
        this.showPanel(1, true);
        this.showPanel(2, true);
        this.showPanel(3, true);
        break;

      case 'lyrics':
        this.workspace.style.gridTemplateColumns = '240px 1.4fr';
        this.showPanel(1, true);
        this.showPanel(2, true);
        this.showPanel(3, false);
        break;

      case 'mastering':
        this.workspace.style.gridTemplateColumns = '1fr 340px';
        this.showPanel(1, false);
        this.showPanel(2, true);
        this.showPanel(3, true);
        break;

      case 'minimal':
        this.workspace.style.gridTemplateColumns = '1fr';
        this.showPanel(1, false);
        this.showPanel(2, true);
        this.showPanel(3, false);
        break;
    }
  }

  showPanel(index, visible) {
    const panel = this.workspace.querySelector(`.dock-panel:nth-child(${index})`);
    if (panel) {
      panel.style.display = visible ? 'flex' : 'none';
    }
  }

  setupLyrics() {
    if (!this.lyricLines) return;

    this.lyricLines.forEach(line => {
      line.addEventListener('click', () => {
        this.lyricLines.forEach(l => l.classList.remove('active'));
        line.classList.add('active');
      });
    });
  }
}
