'use strict';

class BootScene extends Phaser.Scene {
  constructor() {
    super('BootScene');
  }

  create() {
    const G = this.make.graphics({ x: 0, y: 0, add: false });

    // Ball texture (white circle, 20x20)
    G.clear();
    G.fillStyle(0xFFFFFF);
    G.fillCircle(10, 10, 10);
    G.generateTexture('ball', 20, 20);

    // Court bg (drawn per scene, no texture needed)

    // Paddle texture generic (rectangle with handle)
    G.clear();
    G.fillStyle(0xAAAAAA);
    G.fillRoundedRect(0, 0, 18, 40, 4);
    G.generateTexture('paddle_default', 18, 40);

    // Orb textures
    const orbColors = { bronze: 0xCD7F32, silver: 0xC0C0C0, gold: 0xFFD700 };
    Object.entries(orbColors).forEach(([name, color]) => {
      G.clear();
      G.fillStyle(color);
      G.fillCircle(30, 30, 30);
      G.fillStyle(0xFFFFFF, 0.3);
      G.fillCircle(22, 18, 10);
      G.generateTexture(`orb_${name}`, 60, 60);
    });

    G.destroy();
    this.scene.start('MainMenuScene');
  }
}
