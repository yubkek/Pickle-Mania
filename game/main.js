'use strict';

const config = {
  type: Phaser.AUTO,
  width: 400,
  height: 700,
  backgroundColor: '#0a0a1a',
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  scene: [
    BootScene,
    MainMenuScene,
    CampaignScene,
    CharCreationScene,
    GameScene,
    LootScene,
    InventoryScene,
  ],
  input: {
    activePointers: 3,
  },
  render: {
    antialias: true,
    pixelArt: false,
  },
};

// eslint-disable-next-line no-unused-vars
const game = new Phaser.Game(config);
