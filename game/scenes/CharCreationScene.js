'use strict';

class CharCreationScene extends Phaser.Scene {
  constructor() {
    super('CharCreationScene');
  }

  init(data) {
    this.nextScene = data.next || 'campaign';
  }

  create() {
    const W = this.scale.width;
    const H = this.scale.height;

    this.totalPoints = 50;
    this.stats = { moveSpeed: 0, power: 0, health: 0, accuracy: 0 };
    this.charName = 'Pickler';
    this.selectedPreset = -1;

    // Background
    const bg = this.add.graphics();
    bg.fillGradientStyle(0x0a1628, 0x0a1628, 0x0d2d1a, 0x0d2d1a, 1);
    bg.fillRect(0, 0, W, H);

    this.add.text(W / 2, 25, 'CREATE CHARACTER', {
      fontSize: '22px', fill: '#FFD700', fontStyle: 'bold',
      stroke: '#553300', strokeThickness: 4
    }).setOrigin(0.5);

    this.add.text(W / 2, 52, '50 points to allocate', {
      fontSize: '13px', fill: '#AAAAAA'
    }).setOrigin(0.5);

    // Points remaining
    this.pointsText = this.add.text(W / 2, 72, 'Points: 50', {
      fontSize: '18px', fill: '#00FF88', fontStyle: 'bold'
    }).setOrigin(0.5);

    // Stat controls
    const statDefs = [
      { key: 'moveSpeed', label: 'Move Speed', color: '#00AAFF', desc: 'How fast you move' },
      { key: 'power',     label: 'Power',      color: '#FF4444', desc: 'Damage per point won' },
      { key: 'health',    label: 'Health',     color: '#00FF44', desc: 'Starting HP' },
      { key: 'accuracy',  label: 'Accuracy',   color: '#FFD700', desc: 'Shot precision & hit zone size' },
    ];

    this.statTexts = {};
    const startY = 105;

    statDefs.forEach((def, i) => {
      const y = startY + i * 80;

      this.add.text(W / 2 - 95, y, def.label, {
        fontSize: '15px', fill: def.color, fontStyle: 'bold'
      }).setOrigin(0, 0.5);

      this.add.text(W / 2 - 95, y + 18, def.desc, {
        fontSize: '10px', fill: '#888888'
      }).setOrigin(0, 0.5);

      // Minus button
      const minus = this.add.text(W / 2 + 20, y, '−', {
        fontSize: '24px', fill: '#FF4444', padding: { x: 8, y: 4 }
      }).setOrigin(0.5).setInteractive({ useHandCursor: true });
      minus.on('pointerdown', () => this.changeStat(def.key, -1));

      // Value text
      const valText = this.add.text(W / 2 + 50, y, '0', {
        fontSize: '20px', fill: '#FFFFFF', fontStyle: 'bold'
      }).setOrigin(0.5);
      this.statTexts[def.key] = valText;

      // Plus button
      const plus = this.add.text(W / 2 + 80, y, '+', {
        fontSize: '24px', fill: '#00FF88', padding: { x: 8, y: 4 }
      }).setOrigin(0.5).setInteractive({ useHandCursor: true });
      plus.on('pointerdown', () => this.changeStat(def.key, 1));

      // Bar visual
      const barBg = this.add.rectangle(W / 2 - 95, y + 38, 180, 8, 0x333333).setOrigin(0, 0.5);
      this.add.rectangle(W / 2 - 95, y + 38, 180 * (i === 0 ? 0 : 0), 8, parseInt(def.color.replace('#', ''), 16)).setOrigin(0, 0.5);
      this.statBars = this.statBars || {};
      const bar = this.add.rectangle(W / 2 - 95, y + 38, 0, 8, parseInt(def.color.replace('#', ''), 16)).setOrigin(0, 0.5);
      this.statBars[def.key] = { bar, color: parseInt(def.color.replace('#', ''), 16) };
    });

    // Preset buttons
    const presetY = startY + statDefs.length * 80 + 10;
    this.add.text(W / 2, presetY, 'OR CHOOSE A PRESET:', {
      fontSize: '12px', fill: '#888888'
    }).setOrigin(0.5);

    this.presetBtns = [];
    GAME_DATA.presetCharacters.forEach((preset, i) => {
      const x = 50 + (i % 2) * 160;
      const y = presetY + 22 + Math.floor(i / 2) * 44;
      const btn = this.add.text(x, y, preset.name, {
        fontSize: '12px', fill: '#FFFFFF',
        backgroundColor: '#222244', padding: { x: 10, y: 6 },
      }).setInteractive({ useHandCursor: true });
      btn.on('pointerdown', () => this.applyPreset(i));
      this.presetBtns.push(btn);
    });

    // Name input (simplified — tap to cycle names)
    const nameY = presetY + 115;
    this.add.text(W / 2, nameY, 'NAME:', { fontSize: '13px', fill: '#AAAAAA' }).setOrigin(0.5);
    this.nameText = this.add.text(W / 2, nameY + 22, this.charName, {
      fontSize: '18px', fill: '#FFD700', fontStyle: 'bold',
      backgroundColor: '#221100', padding: { x: 12, y: 6 }
    }).setOrigin(0.5).setInteractive({ useHandCursor: true });

    const nameOptions = ['Pickler', 'Ace', 'Dink King', 'Smash Pro', 'Net Ninja', 'Spin Master', 'The Wall'];
    let nameIdx = 0;
    this.nameText.on('pointerdown', () => {
      nameIdx = (nameIdx + 1) % nameOptions.length;
      this.charName = nameOptions[nameIdx];
      this.nameText.setText(this.charName);
    });

    // Start button
    const startBtn = this.add.text(W / 2, H - 35, '▶ START GAME', {
      fontSize: '20px', fill: '#7CFC00', fontStyle: 'bold',
      backgroundColor: '#003300', padding: { x: 20, y: 10 }
    }).setOrigin(0.5).setInteractive({ useHandCursor: true });

    startBtn.on('pointerdown', () => {
      const total = Object.values(this.stats).reduce((a, b) => a + b, 0);
      if (total < 1) {
        this.flashMsg('Allocate at least 1 point!');
        return;
      }
      GameState.character = { ...this.stats, name: this.charName };
      GameState.created = true;
      GameState.save();

      if (this.nextScene === 'campaign') {
        this.scene.start('CampaignScene');
      } else {
        const opponents = GAME_DATA.campaignOpponents;
        const opp = opponents[Math.floor(Math.random() * opponents.length)];
        this.scene.start('GameScene', { opponent: opp, mode: 'ranked', levelIndex: 0 });
      }
    });

    this._msgText = null;
  }

  changeStat(key, delta) {
    const newVal = this.stats[key] + delta;
    const usedPoints = Object.values(this.stats).reduce((a, b) => a + b, 0);
    const remaining = this.totalPoints - usedPoints;

    if (delta > 0 && remaining <= 0) { this.flashMsg('No points left!'); return; }
    if (delta < 0 && newVal < 0) return;
    if (delta > 0 && newVal > 30) { this.flashMsg('Max 30 per stat'); return; }

    this.stats[key] = newVal;
    this.statTexts[key].setText(newVal);

    // Update bar
    const barData = this.statBars[key];
    barData.bar.width = 180 * (newVal / 30);

    // Update points remaining
    const newUsed = Object.values(this.stats).reduce((a, b) => a + b, 0);
    const newRemaining = this.totalPoints - newUsed;
    this.pointsText.setText(`Points: ${newRemaining}`);
    this.pointsText.setFill(newRemaining === 0 ? '#FF4444' : '#00FF88');
  }

  applyPreset(idx) {
    const preset = GAME_DATA.presetCharacters[idx];
    this.stats = { moveSpeed: preset.moveSpeed, power: preset.power, health: preset.health, accuracy: preset.accuracy };
    this.charName = preset.name;
    if (this.nameText) this.nameText.setText(preset.name);

    Object.keys(this.stats).forEach(key => {
      this.statTexts[key].setText(this.stats[key]);
      const barData = this.statBars[key];
      barData.bar.width = 180 * (this.stats[key] / 30);
    });

    const used = Object.values(this.stats).reduce((a, b) => a + b, 0);
    this.pointsText.setText(`Points: ${this.totalPoints - used}`);
    this.pointsText.setFill(used >= this.totalPoints ? '#FF4444' : '#00FF88');

    // Highlight selected preset
    this.presetBtns.forEach((btn, i) => {
      btn.setBackgroundColor(i === idx ? '#004400' : '#222244');
    });
    this.selectedPreset = idx;
  }

  flashMsg(msg) {
    if (this._msgText) this._msgText.destroy();
    this._msgText = this.add.text(this.scale.width / 2, this.scale.height - 70, msg, {
      fontSize: '14px', fill: '#FF4444', stroke: '#000', strokeThickness: 2
    }).setOrigin(0.5);
    this.time.delayedCall(1800, () => { if (this._msgText) { this._msgText.destroy(); this._msgText = null; } });
  }
}
