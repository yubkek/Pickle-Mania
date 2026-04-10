'use strict';

class LootScene extends Phaser.Scene {
  constructor() {
    super('LootScene');
  }

  init(data) {
    this.orbType = data.orbType || 'bronze';
    this.mode = data.mode || 'campaign';
    this.levelIndex = data.levelIndex || 0;
  }

  create() {
    const W = this.scale.width;
    const H = this.scale.height;

    const bg = this.add.graphics();
    bg.fillGradientStyle(0x0a0a1a, 0x0a0a1a, 0x1a0a2a, 0x1a0a2a, 1);
    bg.fillRect(0, 0, W, H);

    const orbColors = { bronze: 0xCD7F32, silver: 0xC0C0C0, gold: 0xFFD700 };
    const orbColor = orbColors[this.orbType];
    const orbName = this.orbType.toUpperCase() + ' ORB';

    this.add.text(W / 2, 40, 'LOOT ORB', {
      fontSize: '26px', fill: '#FFFFFF', fontStyle: 'bold',
      stroke: '#000000', strokeThickness: 4,
    }).setOrigin(0.5);

    this.add.text(W / 2, 70, orbName, {
      fontSize: '20px',
      fill: `#${orbColor.toString(16).padStart(6, '0')}`,
      fontStyle: 'bold',
    }).setOrigin(0.5);

    // Orb graphic
    this.orbGfx = this.add.graphics();
    this.orbX = W / 2;
    this.orbY = H * 0.38;
    this.orbRadius = 60;
    this.orbOpened = false;
    this.drawOrb(orbColor, 1);

    // Tap to open prompt
    this.tapPrompt = this.add.text(W / 2, this.orbY + 85, '✨ TAP TO OPEN ✨', {
      fontSize: '16px', fill: '#FFFFFF', fontStyle: 'bold',
    }).setOrigin(0.5);

    // Pulse animation on prompt
    this.tweens.add({
      targets: this.tapPrompt, alpha: 0.3, yoyo: true, repeat: -1, duration: 700, ease: 'Sine.easeInOut',
    });

    // Make orb interactive
    const hitArea = this.add.circle(W / 2, this.orbY, 70, 0xFFFFFF, 0).setInteractive({ useHandCursor: true });
    hitArea.on('pointerdown', () => {
      if (!this.orbOpened) {
        this.openOrb();
        hitArea.removeInteractive();
      }
    });

    // Sparkle particles setup
    this.sparkles = [];
  }

  drawOrb(color, alpha) {
    const g = this.orbGfx;
    g.clear();
    // Glow
    g.fillStyle(color, 0.15 * alpha);
    g.fillCircle(this.orbX, this.orbY, this.orbRadius + 20);
    g.fillStyle(color, 0.1 * alpha);
    g.fillCircle(this.orbX, this.orbY, this.orbRadius + 35);
    // Main sphere
    g.fillStyle(color, alpha);
    g.fillCircle(this.orbX, this.orbY, this.orbRadius);
    // Shine
    g.fillStyle(0xFFFFFF, 0.4 * alpha);
    g.fillCircle(this.orbX - this.orbRadius * 0.28, this.orbY - this.orbRadius * 0.28, this.orbRadius * 0.32);
    // Inner depth
    g.fillStyle(0x000000, 0.2 * alpha);
    g.fillCircle(this.orbX + this.orbRadius * 0.2, this.orbY + this.orbRadius * 0.2, this.orbRadius * 0.4);
  }

  openOrb() {
    this.orbOpened = true;
    if (this.tapPrompt) { this.tapPrompt.destroy(); this.tapPrompt = null; }

    const W = this.scale.width;
    const orbColors = { bronze: 0xCD7F32, silver: 0xC0C0C0, gold: 0xFFD700 };
    const color = orbColors[this.orbType];

    // Shake + burst animation
    this.tweens.add({
      targets: { x: 0 },
      x: 1,
      duration: 600,
      ease: 'Power2',
      onUpdate: (tween) => {
        const t = tween.progress;
        const shake = Math.sin(t * Math.PI * 12) * 8 * (1 - t);
        this.orbGfx.x = shake;
        this.drawOrb(color, 1);
      },
      onComplete: () => {
        // Flash white
        this.cameras.main.flash(300, 255, 255, 255, false);
        this.orbGfx.setVisible(false);

        // Spawn sparkles
        this.spawnSparkles(color);

        // Roll the loot
        this.time.delayedCall(400, () => this.showReward());
      },
    });
  }

  spawnSparkles(color) {
    const W = this.scale.width;
    for (let i = 0; i < 18; i++) {
      const angle = (i / 18) * Math.PI * 2;
      const speed = 80 + Math.random() * 120;
      const s = this.add.graphics();
      const sx = this.orbX;
      const sy = this.orbY;
      s.fillStyle(color);
      s.fillCircle(0, 0, 5 + Math.random() * 6);
      s.x = sx;
      s.y = sy;
      this.sparkles.push(s);

      this.tweens.add({
        targets: s,
        x: sx + Math.cos(angle) * speed,
        y: sy + Math.sin(angle) * speed,
        alpha: 0,
        scaleX: 0.2,
        scaleY: 0.2,
        duration: 700 + Math.random() * 400,
        ease: 'Power2',
        onComplete: () => s.destroy(),
      });
    }
  }

  rollLoot() {
    const table = GAME_DATA.lootTables[this.orbType];
    const weights = table.rarityWeights;
    const roll = Math.random();

    let rarity;
    if (roll < weights.A) rarity = 'A';
    else if (roll < weights.A + weights.B) rarity = 'B';
    else rarity = 'C';

    // Randomly pick paddle or superpower
    const isPaddle = Math.random() < 0.5;
    const pool = isPaddle
      ? GAME_DATA.paddles.filter(p => p.rarity === rarity)
      : GAME_DATA.superpowers.filter(p => p.rarity === rarity);

    if (pool.length === 0) {
      // Fallback to C rarity
      const fallback = isPaddle
        ? GAME_DATA.paddles.filter(p => p.rarity === 'C')
        : GAME_DATA.superpowers.filter(p => p.rarity === 'C');
      return { type: isPaddle ? 'paddle' : 'power', item: fallback[Math.floor(Math.random() * fallback.length)], rarity: 'C' };
    }

    const item = pool[Math.floor(Math.random() * pool.length)];
    return { type: isPaddle ? 'paddle' : 'power', item, rarity };
  }

  showReward() {
    const W = this.scale.width;
    const H = this.scale.height;
    const reward = this.rollLoot();

    // Save to inventory
    GameState.addToInventory(reward.type, reward.item.id);

    const rarityColor = GAME_DATA.rarityColors[reward.rarity];
    const rarityName = GAME_DATA.rarityNames[reward.rarity];

    // Reward panel
    const panelBg = this.add.rectangle(W / 2, H * 0.45, W - 40, 220, 0x111122).setOrigin(0.5);
    panelBg.setStrokeStyle(3, reward.item.color || 0xFFFFFF);

    // Rarity badge
    this.add.text(W / 2, H * 0.45 - 90, rarityName.toUpperCase(), {
      fontSize: '14px', fill: rarityColor, fontStyle: 'bold',
      backgroundColor: '#000000', padding: { x: 10, y: 4 },
    }).setOrigin(0.5);

    // Item type icon
    const typeIcon = reward.type === 'paddle' ? '🏓' : '⚡';
    this.add.text(W / 2, H * 0.45 - 62, typeIcon + ' ' + (reward.type === 'paddle' ? 'PADDLE' : 'SUPERPOWER'), {
      fontSize: '13px', fill: '#AAAAAA',
    }).setOrigin(0.5);

    // Item color swatch
    const swatch = this.add.graphics();
    swatch.fillStyle(reward.item.color || 0xAAAAAA);
    swatch.fillCircle(W / 2, H * 0.45 - 28, 24);
    swatch.lineStyle(3, 0xFFFFFF, 0.5);
    swatch.strokeCircle(W / 2, H * 0.45 - 28, 24);

    // Item name (animated)
    const nameText = this.add.text(W / 2, H * 0.45 + 10, reward.item.name, {
      fontSize: '24px', fill: '#FFFFFF', fontStyle: 'bold',
      stroke: '#000000', strokeThickness: 3,
    }).setOrigin(0.5).setAlpha(0).setScale(0.5);

    this.tweens.add({
      targets: nameText, alpha: 1, scaleX: 1, scaleY: 1,
      duration: 500, ease: 'Back.easeOut',
    });

    // Description
    this.add.text(W / 2, H * 0.45 + 44, reward.item.desc, {
      fontSize: '13px', fill: '#AAAAAA', wordWrap: { width: W - 80 },
    }).setOrigin(0.5);

    // Stats if paddle
    if (reward.type === 'paddle') {
      this.add.text(W / 2, H * 0.45 + 72, `Power: ×${reward.item.power}  Accuracy: ×${reward.item.accuracy}`, {
        fontSize: '12px', fill: '#88AAFF',
      }).setOrigin(0.5);
    }

    // Duplicate warning
    if (GameState.hasItem(reward.type, reward.item.id)) {
      this.add.text(W / 2, H * 0.45 + 95, '(duplicate — added to collection)', {
        fontSize: '10px', fill: '#555555',
      }).setOrigin(0.5);
    }

    // Equip button (if paddle or power)
    const equipBtn = this.add.text(W / 2, H * 0.7, reward.type === 'paddle' ? '✓ EQUIP PADDLE' : '✓ EQUIP POWER', {
      fontSize: '16px', fill: '#00FF88', fontStyle: 'bold',
      backgroundColor: '#003322', padding: { x: 14, y: 8 },
    }).setOrigin(0.5).setInteractive({ useHandCursor: true });

    equipBtn.on('pointerdown', () => {
      if (reward.type === 'paddle') {
        GameState.equippedPaddle = reward.item.id;
      } else {
        const powers = GameState.equippedPowers || [];
        if (!powers.includes(reward.item.id) && powers.length < 3) {
          powers.push(reward.item.id);
          GameState.equippedPowers = powers;
        }
      }
      GameState.save();
      equipBtn.setFill('#AAAAAA').setBackgroundColor('#111111').setText('✓ EQUIPPED');
      equipBtn.removeInteractive();
    });

    // Continue buttons
    if (this.mode === 'campaign') {
      const nextLevelIdx = this.levelIndex + 1;
      const hasNext = nextLevelIdx < GAME_DATA.campaignOpponents.length;

      if (hasNext) {
        const nextBtn = this.add.text(W / 2, H * 0.8, '▶ NEXT OPPONENT', {
          fontSize: '18px', fill: '#7CFC00', fontStyle: 'bold',
          backgroundColor: '#003300', padding: { x: 14, y: 8 },
        }).setOrigin(0.5).setInteractive({ useHandCursor: true });
        nextBtn.on('pointerdown', () => {
          this.scene.start('GameScene', {
            opponent: GAME_DATA.campaignOpponents[nextLevelIdx],
            mode: 'campaign',
            levelIndex: nextLevelIdx,
          });
        });
      }
    }

    const menuBtn = this.add.text(W / 2, H * 0.9, '← Main Menu', {
      fontSize: '15px', fill: '#AAAAAA', padding: { x: 10, y: 6 },
    }).setOrigin(0.5).setInteractive({ useHandCursor: true });
    menuBtn.on('pointerdown', () => this.scene.start('MainMenuScene'));
  }
}
