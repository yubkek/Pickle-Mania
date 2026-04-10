'use strict';

class MainMenuScene extends Phaser.Scene {
  constructor() {
    super('MainMenuScene');
  }

  create() {
    const W = this.scale.width;
    const H = this.scale.height;

    // Background gradient
    const bg = this.add.graphics();
    bg.fillGradientStyle(0x0a1628, 0x0a1628, 0x0d2d1a, 0x0d2d1a, 1);
    bg.fillRect(0, 0, W, H);

    // Decorative court lines
    const lines = this.add.graphics();
    lines.lineStyle(1, 0x2d5a1b, 0.6);
    lines.strokeRect(30, H * 0.3, W - 60, H * 0.4);
    lines.lineStyle(2, 0x3a7a25, 0.4);
    lines.lineBetween(30, H * 0.5, W - 30, H * 0.5);
    lines.lineBetween(W / 2, H * 0.3, W / 2, H * 0.7);

    // Title
    this.add.text(W / 2, H * 0.15, 'PICKLE', {
      fontSize: '56px',
      fill: '#7CFC00',
      fontStyle: 'bold',
      stroke: '#003300',
      strokeThickness: 6,
    }).setOrigin(0.5);

    this.add.text(W / 2, H * 0.15 + 62, 'MANIA', {
      fontSize: '42px',
      fill: '#FFD700',
      fontStyle: 'bold',
      stroke: '#553300',
      strokeThickness: 5,
    }).setOrigin(0.5);

    this.add.text(W / 2, H * 0.15 + 105, '🏓 Pickleball Evolved 🏓', {
      fontSize: '14px',
      fill: '#AAFFAA',
    }).setOrigin(0.5);

    // Player info if created
    if (GameState.created) {
      const lvlText = this.add.text(W / 2, H * 0.35, `LVL ${GameState.level} · ${GameState.character.name}`, {
        fontSize: '14px', fill: '#AAAAFF'
      }).setOrigin(0.5);

      // XP bar
      const xpBg = this.add.rectangle(W / 2, H * 0.35 + 22, 180, 10, 0x333333).setOrigin(0.5);
      const xpPct = GameState.xpProgress();
      this.add.rectangle(W / 2 - 90, H * 0.35 + 22, 180 * xpPct, 10, 0x00AAFF).setOrigin(0, 0.5);
      this.add.text(W / 2, H * 0.35 + 33, `${GameState.xp} XP`, { fontSize: '10px', fill: '#8888FF' }).setOrigin(0.5);
    }

    // Buttons
    const btnY = H * 0.52;
    const btnSpacing = 62;

    this.makeButton(W / 2, btnY, 'CAMPAIGN', '#7CFC00', '#003300', () => {
      if (!GameState.created) {
        this.scene.start('CharCreationScene', { next: 'campaign' });
      } else {
        this.scene.start('CampaignScene');
      }
    });

    const rankLocked = GameState.level < GAME_DATA.rankUnlockLevel;
    this.makeButton(W / 2, btnY + btnSpacing, 'RANKED' + (rankLocked ? ` (LVL ${GAME_DATA.rankUnlockLevel})` : ''), rankLocked ? '#666666' : '#FFD700', rankLocked ? '#222222' : '#443300', () => {
      if (rankLocked) {
        this.flashMsg(`Unlock Ranked at Level ${GAME_DATA.rankUnlockLevel}!`);
        return;
      }
      if (!GameState.created) {
        this.scene.start('CharCreationScene', { next: 'ranked' });
      } else {
        this.startRanked();
      }
    });

    this.makeButton(W / 2, btnY + btnSpacing * 2, 'INVENTORY', '#00AAFF', '#001133', () => {
      this.scene.start('InventoryScene');
    });

    if (GameState.created) {
      this.makeButton(W / 2, btnY + btnSpacing * 3, 'RESET SAVE', '#FF4444', '#330000', () => {
        GameState.reset();
        this.scene.restart();
      }, true);
    }

    // Version
    this.add.text(W - 8, H - 8, 'v1.0', { fontSize: '10px', fill: '#444444' }).setOrigin(1, 1);

    this._msgText = null;
  }

  makeButton(x, y, label, fillColor, bgColor, callback, small = false) {
    const size = small ? 14 : 18;
    const padX = small ? 14 : 22;
    const padY = small ? 6 : 10;

    const txt = this.add.text(x, y, label, {
      fontSize: `${size}px`,
      fill: fillColor,
      backgroundColor: bgColor,
      padding: { x: padX, y: padY },
      fontStyle: 'bold',
    }).setOrigin(0.5).setInteractive({ useHandCursor: true });

    txt.on('pointerover', () => txt.setAlpha(0.8));
    txt.on('pointerout', () => txt.setAlpha(1));
    txt.on('pointerdown', callback);
    return txt;
  }

  startRanked() {
    const opponents = GAME_DATA.campaignOpponents;
    const opponent = opponents[Math.floor(Math.random() * opponents.length)];
    this.scene.start('GameScene', { opponent, mode: 'ranked', levelIndex: 0 });
  }

  flashMsg(msg) {
    if (this._msgText) this._msgText.destroy();
    this._msgText = this.add.text(this.scale.width / 2, this.scale.height * 0.9, msg, {
      fontSize: '16px', fill: '#FFD700', stroke: '#000', strokeThickness: 3
    }).setOrigin(0.5);
    this.time.delayedCall(2000, () => { if (this._msgText) { this._msgText.destroy(); this._msgText = null; } });
  }
}

// Simple campaign level select scene
class CampaignScene extends Phaser.Scene {
  constructor() { super('CampaignScene'); }

  create() {
    const W = this.scale.width;
    const H = this.scale.height;

    const bg = this.add.graphics();
    bg.fillGradientStyle(0x0a1628, 0x0a1628, 0x0d2d1a, 0x0d2d1a, 1);
    bg.fillRect(0, 0, W, H);

    this.add.text(W / 2, 30, 'CAMPAIGN', {
      fontSize: '28px', fill: '#7CFC00', fontStyle: 'bold',
      stroke: '#003300', strokeThickness: 4
    }).setOrigin(0.5);

    this.add.text(W / 2, 60, `Progress: ${GameState.campaignProgress}/${GAME_DATA.campaignOpponents.length}`, {
      fontSize: '14px', fill: '#AAAAAA'
    }).setOrigin(0.5);

    const startY = 100;
    const spacing = 90;

    GAME_DATA.campaignOpponents.forEach((opp, i) => {
      const unlocked = i <= GameState.campaignProgress;
      const beaten = i < GameState.campaignProgress;
      const y = startY + i * spacing;

      const cardBg = this.add.rectangle(W / 2, y + 30, W - 60, 75,
        beaten ? 0x1a3a1a : unlocked ? 0x1a2a3a : 0x1a1a1a).setOrigin(0.5);
      cardBg.setStrokeStyle(2, beaten ? 0x7CFC00 : unlocked ? 0x00AAFF : 0x333333);

      this.add.text(W / 2, y + 12, opp.name, {
        fontSize: '18px',
        fill: beaten ? '#7CFC00' : unlocked ? '#FFFFFF' : '#555555',
        fontStyle: 'bold'
      }).setOrigin(0.5);

      this.add.text(W / 2, y + 34, `Level ${opp.level}  ·  ${beaten ? '✓ BEATEN' : unlocked ? 'CHALLENGE' : '🔒 LOCKED'}`, {
        fontSize: '12px',
        fill: beaten ? '#7CFC00' : unlocked ? '#AAAAAA' : '#555555'
      }).setOrigin(0.5);

      const paddle = GAME_DATA.paddles.find(p => p.id === opp.paddle);
      const rColor = GAME_DATA.rarityColors[paddle ? paddle.rarity : 'C'];
      this.add.text(W / 2, y + 54, `Paddle: ${paddle ? paddle.name : '?'}`, {
        fontSize: '11px', fill: rColor
      }).setOrigin(0.5);

      if (unlocked) {
        cardBg.setInteractive({ useHandCursor: true });
        cardBg.on('pointerover', () => cardBg.setAlpha(0.8));
        cardBg.on('pointerout', () => cardBg.setAlpha(1));
        cardBg.on('pointerdown', () => {
          this.scene.start('GameScene', { opponent: opp, mode: 'campaign', levelIndex: i });
        });
      }
    });

    const backBtn = this.add.text(W / 2, H - 30, '← BACK', {
      fontSize: '16px', fill: '#AAAAAA', padding: { x: 12, y: 6 }
    }).setOrigin(0.5).setInteractive({ useHandCursor: true });
    backBtn.on('pointerdown', () => this.scene.start('MainMenuScene'));
  }
}
