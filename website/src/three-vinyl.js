/**
 * STUDIO — 3D Vinyl Turntable Simulation (Three.js WebGL)
 * Fixed & Polished:
 * - High-precision concentric sound grooves with anisotropic sheen
 * - Studio official icon & typography on center label
 * - Flat turntable platter staging (no intersecting sleeve geometry)
 * - Spin around central spindle axis with smooth inertia physics
 * - Smooth pointer tilt parallax & dynamic OKLCH accent lighting
 */

export class StudioVinylStage {
  constructor(containerId) {
    this.container = document.getElementById(containerId);
    if (!this.container) return;

    this.isPlaying = true;
    this.spinSpeed = 0.012;
    this.currentSpin = 0.012;
    this.baseTiltX = 0.42; // Elegant tilt towards camera
    this.targetTiltX = this.baseTiltX;
    this.targetTiltY = 0;
    this.currentTiltX = this.baseTiltX;
    this.currentTiltY = 0;
    this.accentHex = '#E28A36';

    this.init();
  }

  init() {
    if (typeof THREE === 'undefined') {
      console.warn('Three.js not loaded, vinyl 3D will fallback gracefully.');
      return;
    }

    const width = this.container.clientWidth;
    const height = this.container.clientHeight;

    // Scene
    this.scene = new THREE.Scene();

    // Camera
    this.camera = new THREE.PerspectiveCamera(34, width / height, 0.1, 100);
    this.camera.position.set(0, 0, 8.2);

    // Renderer
    this.renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: true,
      powerPreference: 'high-performance'
    });
    this.renderer.setSize(width, height);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.25;

    this.container.appendChild(this.renderer.domElement);

    // Build Turntable & Vinyl
    this.createTurntable();

    // Lighting
    this.setupLighting();

    // Event Listeners
    this.setupEvents();

    // Animation Loop
    this.animate = this.animate.bind(this);
    requestAnimationFrame(this.animate);
  }

  generateVinylTexture() {
    const size = 1024;
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    const center = size / 2;
    const maxRadius = size / 2 - 16;
    const labelRadius = size * 0.18;

    // Base vinyl obsidian black
    ctx.fillStyle = '#100E0C';
    ctx.fillRect(0, 0, size, size);

    // Outer rim bevel
    ctx.beginPath();
    ctx.arc(center, center, maxRadius, 0, Math.PI * 2);
    ctx.strokeStyle = '#221F1B';
    ctx.lineWidth = 8;
    ctx.stroke();

    // Sound grooves with subtle anisotropic micro-sheen
    for (let r = labelRadius + 18; r < maxRadius - 6; r += 1.6) {
      const alpha = 0.03 + (Math.sin(r * 0.35) * 0.02) + (Math.random() * 0.02);
      ctx.beginPath();
      ctx.arc(center, center, r, 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(255, 255, 255, ${alpha})`;
      ctx.lineWidth = 0.9;
      ctx.stroke();
    }

    // Lead-out runout grooves
    for (let r = labelRadius + 4; r < labelRadius + 16; r += 3) {
      ctx.beginPath();
      ctx.arc(center, center, r, 0, Math.PI * 2);
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.06)';
      ctx.lineWidth = 1.2;
      ctx.stroke();
    }

    // Center Label Background
    ctx.beginPath();
    ctx.arc(center, center, labelRadius, 0, Math.PI * 2);
    ctx.fillStyle = '#171513';
    ctx.fill();

    // Center Label Accent Ring
    ctx.beginPath();
    ctx.arc(center, center, labelRadius - 2, 0, Math.PI * 2);
    ctx.strokeStyle = this.accentHex;
    ctx.lineWidth = 4;
    ctx.stroke();

    // Studio Official Logo on Center Label
    const logoR = 36;
    const logoCenterY = center - 22;

    // Top-left arc (muted beige)
    ctx.beginPath();
    ctx.arc(center, logoCenterY, logoR, Math.PI * 0.7, Math.PI * 1.5);
    ctx.strokeStyle = '#C8C0B2';
    ctx.lineWidth = 3.5;
    ctx.lineCap = 'round';
    ctx.stroke();

    // Remainder arc (accent)
    ctx.beginPath();
    ctx.arc(center, logoCenterY, logoR, Math.PI * 1.5, Math.PI * 2.7);
    ctx.strokeStyle = this.accentHex;
    ctx.lineWidth = 3.5;
    ctx.lineCap = 'round';
    ctx.stroke();

    // Node dot
    const dotAngle = Math.PI * 0.72;
    const dotX = center + Math.cos(dotAngle) * logoR;
    const dotY = logoCenterY + Math.sin(dotAngle) * logoR;
    ctx.beginPath();
    ctx.arc(dotX, dotY, 6, 0, Math.PI * 2);
    ctx.fillStyle = this.accentHex;
    ctx.fill();

    // Label Typography
    ctx.textAlign = 'center';
    ctx.fillStyle = '#EAE7E4';
    ctx.font = '600 20px "Spectral", Georgia, serif';
    ctx.fillText('S T U D I O', center, center + 32);

    ctx.font = '500 11px "JetBrains Mono", monospace';
    ctx.fillStyle = '#898680';
    ctx.fillText('33 ⅓ RPM  •  LOSSLESS', center, center + 50);

    ctx.font = '400 10px "Work Sans", sans-serif';
    ctx.fillStyle = this.accentHex;
    ctx.fillText('SOLARIS (MIDNIGHT TAPE)', center, center + 66);

    // Center Spindle Hole (Pure black center)
    ctx.beginPath();
    ctx.arc(center, center, 14, 0, Math.PI * 2);
    ctx.fillStyle = '#050505';
    ctx.fill();

    const texture = new THREE.CanvasTexture(canvas);
    texture.generateMipmaps = true;
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    return texture;
  }

  createTurntable() {
    this.turntableGroup = new THREE.Group();

    // 1. Platter Base (Thin circular isolated platform beneath vinyl)
    const platterGeo = new THREE.CylinderGeometry(2.65, 2.7, 0.12, 64);
    const platterMat = new THREE.MeshStandardMaterial({
      color: 0x161412,
      roughness: 0.5,
      metalness: 0.8
    });
    this.platterMesh = new THREE.Mesh(platterGeo, platterMat);
    this.platterMesh.position.y = -0.09;
    this.turntableGroup.add(this.platterMesh);

    // Subtle edge metallic ring for platter
    const ringGeo = new THREE.TorusGeometry(2.7, 0.02, 16, 64);
    const ringMat = new THREE.MeshStandardMaterial({
      color: 0x332E2A,
      roughness: 0.3,
      metalness: 0.9
    });
    const ringMesh = new THREE.Mesh(ringGeo, ringMat);
    ringMesh.rotation.x = Math.PI / 2;
    ringMesh.position.y = -0.09;
    this.turntableGroup.add(ringMesh);

    // 2. Vinyl Disc (Thin cylinder with realistic diameter and top vinyl texture)
    const vinylRadius = 2.5;
    const vinylThickness = 0.04;
    const vinylGeo = new THREE.CylinderGeometry(vinylRadius, vinylRadius, vinylThickness, 64);

    this.vinylTexture = this.generateVinylTexture();

    const discTopMat = new THREE.MeshStandardMaterial({
      map: this.vinylTexture,
      roughness: 0.32,
      metalness: 0.65
    });

    const discEdgeMat = new THREE.MeshStandardMaterial({
      color: 0x141210,
      roughness: 0.2,
      metalness: 0.8
    });

    // Material array: 0: edge, 1: top, 2: bottom
    this.vinylMesh = new THREE.Mesh(vinylGeo, [discEdgeMat, discTopMat, discEdgeMat]);
    this.vinylMesh.position.y = 0;
    this.turntableGroup.add(this.vinylMesh);

    // 3. Center Metallic Spindle Pin
    const spindleGeo = new THREE.CylinderGeometry(0.06, 0.06, 0.35, 32);
    const spindleMat = new THREE.MeshStandardMaterial({
      color: 0xCCCCCC,
      roughness: 0.2,
      metalness: 0.95
    });
    const spindleMesh = new THREE.Mesh(spindleGeo, spindleMat);
    spindleMesh.position.y = 0.15;
    this.turntableGroup.add(spindleMesh);

    // Base orientation
    this.turntableGroup.rotation.x = this.baseTiltX;
    this.scene.add(this.turntableGroup);
  }

  setupLighting() {
    // Soft ambient illumination
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.45);
    this.scene.add(ambientLight);

    // Main Key Light from top-front
    this.keyLight = new THREE.DirectionalLight(0xfff6ea, 2.0);
    this.keyLight.position.set(3, 7, 6);
    this.scene.add(this.keyLight);

    // Specular Grazing Light (creates the vinyl anisotropic groove sheen)
    this.sheenLight = new THREE.DirectionalLight(0xffffff, 1.4);
    this.sheenLight.position.set(-5, 5, 2);
    this.scene.add(this.sheenLight);

    // Dynamic Accent Rim Light (matches user theme hue)
    this.accentLight = new THREE.PointLight(this.accentHex, 3.2, 14);
    this.accentLight.position.set(-3.2, -1.8, 3.0);
    this.scene.add(this.accentLight);
  }

  setupEvents() {
    const onPointerMove = (e) => {
      const rect = this.container.getBoundingClientRect();
      const x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
      const y = -(((e.clientY - rect.top) / rect.height) * 2 - 1);

      this.targetTiltY = x * 0.38;
      this.targetTiltX = this.baseTiltX - (y * 0.22);
    };

    window.addEventListener('mousemove', onPointerMove);

    window.addEventListener('resize', () => {
      if (!this.container) return;
      const width = this.container.clientWidth;
      const height = this.container.clientHeight;
      this.camera.aspect = width / height;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(width, height);
    });
  }

  togglePlay(forceState) {
    this.isPlaying = (forceState !== undefined) ? forceState : !this.isPlaying;
  }

  setAccentColor(hexColor) {
    this.accentHex = hexColor;
    if (this.accentLight) {
      this.accentLight.color.set(hexColor);
    }
    // Regenerate texture with updated accent ring and logo
    if (this.vinylMesh) {
      this.vinylTexture = this.generateVinylTexture();
      this.vinylMesh.material[1].map = this.vinylTexture;
      this.vinylMesh.material[1].needsUpdate = true;
    }
  }

  animate() {
    requestAnimationFrame(this.animate);

    // Spin physics around Y axis (the central spindle)
    const targetSpin = this.isPlaying ? this.spinSpeed : 0.0005;
    this.currentSpin += (targetSpin - this.currentSpin) * 0.06;

    if (this.vinylMesh) {
      this.vinylMesh.rotation.y += this.currentSpin;
    }

    // Smooth camera / stage tilt damping
    this.currentTiltX += (this.targetTiltX - this.currentTiltX) * 0.06;
    this.currentTiltY += (this.targetTiltY - this.currentTiltY) * 0.06;

    if (this.turntableGroup) {
      this.turntableGroup.rotation.x = this.currentTiltX;
      this.turntableGroup.rotation.y = this.currentTiltY;
    }

    this.renderer.render(this.scene, this.camera);
  }
}
