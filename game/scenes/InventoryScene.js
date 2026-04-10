'use strict';

class InventoryScene extends Phaser.Scene {
  constructor() {
    super('InventoryScene');
  }

  create() {
    const W = this.scale.width;
    const H = this.scale.height;

    const bg = this.add.graphics();
    bg.fillGradientStyle(0x0a1628, 0x0a1628, 0x1a1030, 0x1a1030, 1);
    bg.fillRect(0, 0, W, H);

    this.add.text(W / 2, 22, 'INVENTORY', {
      fontSize: '24px', fill: '#FFD700', fontStyle: 'bold',
      stroke: '#553300', strokeThickness: 4,
    }).setOrigin(0.5);

    // Tabs
    this.activeTab = 'paddles';
    const tabY = 50;

    const paddleTab = this.add.text(W / 2 - 60, tabY, 'PADDLES', {
      fontSize: '14px', fill: '#FFFFFF', backgroundColor: '#223344', padding: { x: 10, y: 5 },
    }).setOrigin(0.5).setInteractive({ useHandCursor: true });

    const powerTab = this.add.text(W / 2 + 60, tabY, 'POWERS', {
      fontSize: '14px', fill: '#FFFFFF', backgroundColor: '#223344', padding: { x: 10, y: 5 },
    }).setOrigin(0.5).setInteractive({ useHandCursor: true });

    this.contentContainer = this.add.container(0, 0);
    this.showTab('paddles');

    paddleTab.on('pointerdown', () => {
      this.activeTab = 'paddles';
      paddleTab.setBackgroundColor('#004466');
      powerTab.setBackgroundColor('#223344');
      this.showTab('paddles');
    });

    powerTab.on('pointerdown', () => {
      this.activeTab = 'powers';
      paddleTab.setBackgroundColor('#223344');
      powerTab.setBackgroundColor('#004466');
      this.showTab('powers');
    });

    paddleTab.setBackgroundColor('#004466');

    // Equipped panel
    this.add.text(W / 2, H - 88, 'EQUIPPED PADDLE:', { fontSize: '11px', fill: '#888888' }).setOrigin(0.5);
    const eqPaddle = GAME_DATA.paddles.find(p => p.id === GameState.equippedPaddle) || GAME_DATA.paddles[0];
    this.equippedPaddleText = this.add.text(W / 2, H - 72, eqPaddle.name, {
      fontSize: '14px', fill: `#${eqPaddle.color.toString(16).padStart(6, '0')}`, fontStyle: 'bold',
    }).setOrigin(0.5);

    this.add.text(W / 2, H - 52, `POWERS (${(GameState.equippedPowers || []).length}/3): ${(GameState.equippedPowers || []).join(', ') || 'none'}`, {
      fontSize: '10px', fill: '#AAAAAA', wordWrap: { width: W - 20 },
    }).setOrigin(0.5);

    const backBtn = this.add.text(W / 2, H - 22, '← BACK', {
      fontSize: '15px', fill: '#AAAAAA', padding: { x: 12, y: 6 },
    }).setOrigin(0.5).setInteractive({ useHandCursor: true });
    backBtn.on('pointerdown', () => this.scene.start('MainMenuScene'));
  }

  showTab(tab) {
    this.contentContainer.removeAll(true);

    const W = this.scale.width;
    const inventory = GameState.inventory || [];

    if (tab === 'paddles') {
      const owned = new Set(inventory.filter(i => i.type === 'paddle').map(i => i.id));
      const startY = 75;

      GAME_DATA.paddles.forEach((paddle, i) => {
        const col = i % 2;
        const row = Math.floor(i / 2);
        const x = 30 + col * ((W - 60) / 2 + 10);
        const y = startY + row * 90;

        const isOwned = owned.has(paddle.id);
        const isEquipped = GameState.equippedPaddle === paddle.id;

        const cardBg = this.add.rectangle(x + (W - 60) / 4, y + 35, (W - 60) / 2, 80,
          isEquipped ? 0x003344 : isOwned ? 0x1a1a2a : 0x0d0d16).setOrigin(0.5);
        cardBg.setStrokeStyle(2,
          isEquipped ? 0x00AAFF : isOwned ? parseInt(GAME_DATA.rarityColors[paddle.rarity].replace('#', ''), 16) : 0x222222);

        // Paddle color swatch
        const swatchGfx = this.add.graphics();
        swatchGfx.fillStyle(isOwned ? paddle.color : 0x333333);
        swatchGfx.fillCircle(x + 20, y + 35, 14);

        const nameText = this.add.text(x + 40, y + 20, paddle.name, {
          fontSize: '12px',
          fill: isOwned ? '#FFFFFF' : '#444444',
          fontStyle: isEquipped ? 'bold' : 'normal',
        });

        const rarityText = this.add.text(x + 40, y + 36, GAME_DATA.rarityNames[paddle.rarity], {
          fontSize: '10px',
          fill: isOwned ? GAME_DATA.rarityColors[paddle.rarity] : '#333333',
        });

        if (isOwned) {
          const statText = this.add.text(x + 40, y + 50, `Pow:×${paddle.power} Acc:×${paddle.accuracy}`, {
            fontSize: '9px', fill: '#888888',
          });
          this.contentContainer.add(statText);
        }

        if (isEquipped) {
          const eqBadge = this.add.text(x + (W - 60) / 2 - 5, y + 16, '✓', {
            fontSize: '14px', fill: '#00AAFF',
          }).setOrigin(1, 0);
          this.contentContainer.add(eqBadge);
        }

        if (isOwned && !isEquipped) {
          cardBg.setInteractive({ useHandCursor: true });
          cardBg.on('pointerdown', () => {
            GameState.equippedPaddle = paddle.id;
            GameState.save();
            this.scene.restart();
          });
        }

        if (!isOwned) {
          const lockText = this.add.text(x + (W - 60) / 2 - 5, y + 16, '🔒', {
            fontSize: '12px',
          }).setOrigin(1, 0);
          this.contentContainer.add(lockText);
        }

        this.contentContainer.add([cardBg, swatchGfx, nameText, rarityText]);
      });

    } else {
      // Powers tab
      const owned = new Set(inventory.filter(i => i.type === 'power').map(i => i.id));
      const equipped = new Set(GameState.equippedPowers || []);
      const startY = 75;

      GAME_DATA.superpowers.forEach((power, i) => {
        const y = startY + i * 72;
        const isOwned = owned.has(power.id);
        const isEquipped = equipped.has(power.id);

        const cardBg = this.add.rectangle(W / 2, y + 28, W - 40, 62,
          isEquipped ? 0x1a1a00 : isOwned ? 0x1a1a2a : 0x0d0d16).setOrigin(0.5);
        cardBg.setStrokeStyle(2, isEquipped ? 0xFFFF00 : isOwned ? power.color : 0x222222);

        const swatchGfx = this.add.graphics();
        swatchGfx.fillStyle(isOwned ? power.color : 0x333333);
        swatchGfx.fillCircle(30, y + 28, 16);

        const nameText = this.add.text(56, y + 14, power.name, {
          fontSize: '14px', fill: isOwned ? '#FFFFFF' : '#444444', fontStyle: 'bold',
        });

        const descText = this.add.text(56, y + 32, power.desc, {
          fontSize: '10px', fill: isOwned ? '#888888' : '#333333', wordWrap: { width: W - 100 },
        });

        const rarityBadge = this.add.text(W - 25, y + 14, GAME_DATA.rarityNames[power.rarity], {
          fontSize: '10px', fill: isOwned ? GAME_DATA.rarityColors[power.rarity] : '#333333',
        }).setOrigin(1, 0);

        if (isEquipped) {
          const badge = this.add.text(W - 25, y + 36, '✓ EQUIPPED', {
            fontSize: '10px', fill: '#FFFF00',
          }).setOrigin(1, 0);
          this.contentContainer.add(badge);
        }

        if (isOwned && !isEquipped) {
          cardBg.setInteractive({ useHandCursor: true });
          cardBg.on('pointerdown', () => {
            const powers = GameState.equippedPowers || [];
            if (powers.length >= 3) {
              // Replace oldest
              powers.shift();
            }
            if (!powers.includes(power.id)) powers.push(power.id);
            GameState.equippedPowers = powers;
            GameState.save();
            this.scene.restart();
          });
        }

        if (!isOwned) {
          const lockText = this.add.text(W - 25, y + 14, '🔒', { fontSize: '12px' }).setOrigin(1, 0);
          this.contentContainer.add(lockText);
        }

        this.contentContainer.add([cardBg, swatchGfx, nameText, descText, rarityBadge]);
      });
    }
  }
}
