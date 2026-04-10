'use strict';

class GameScene extends Phaser.Scene {
  constructor() {
    super('GameScene');
  }

  init(data) {
    this.opponentData = data.opponent;
    this.mode = data.mode || 'campaign';
    this.levelIndex = data.levelIndex || 0;
  }

  create() {
    const W = this.scale.width;
    const H = this.scale.height;
    this.W = W;
    this.H = H;
    this.NET_Y = Math.round(H * 0.44);

    // Player stats from saved state
    const cs = GameState.character;
    this.playerStats = { ...cs };
    this.playerMaxHP = Math.round(50 + cs.health * 2.5);
    this.playerHP = this.playerMaxHP;

    const os = this.opponentData.stats;
    this.opponentMaxHP = Math.round(50 + os.health * 2.5);
    this.opponentHP = this.opponentMaxHP;

    // Court boundary margins
    this.MARGIN = 28;

    this.drawCourt();
    this.createEntities();
    this.createJoystick();
    this.setupInput();
    this.createUI();

    // Game state flags
    this.gameOver = false;
    this.playerServing = true;
    this.ballInPlayerZone = false;
    this.ballActive = false;
    this.canHit = false;
    this.lastHitTime = 0;
    this.hitCooldown = 350;
    this.activePowers = new Set();
    this.shieldActive = false;
    this.ballSpin = 0;

    // Hit zone size based on accuracy
    this.baseHitZone = 55 + cs.accuracy * 1.8;

    // Copy equipped powers for this match session
    this.sessionPowers = [...(GameState.equippedPowers || [])];

    // Serve after a brief delay
    this.time.delayedCall(800, () => this.serveBall());
  }

  // ─── COURT ─────────────────────────────────────────────────────────────────

  drawCourt() {
    const { W, H, NET_Y, MARGIN } = this;
    const g = this.add.graphics();

    // Court surface
    g.fillStyle(0x2d5a1b);
    g.fillRect(0, 0, W, H);

    // Opponent side (slightly lighter)
    g.fillStyle(0x346620);
    g.fillRect(MARGIN, 45, W - MARGIN * 2, NET_Y - 45 - 4);

    // Player side
    g.fillStyle(0x2d5a1b);
    g.fillRect(MARGIN, NET_Y + 4, W - MARGIN * 2, H - NET_Y - 4 - 45);

    // Outer boundary
    g.lineStyle(3, 0xFFFFFF, 0.9);
    g.strokeRect(MARGIN, 45, W - MARGIN * 2, H - 90);

    // Net
    g.lineStyle(5, 0xEEEEEE, 1);
    g.lineBetween(MARGIN, NET_Y, W - MARGIN, NET_Y);
    g.fillStyle(0xCCCCCC);
    g.fillCircle(MARGIN, NET_Y, 5);
    g.fillCircle(W - MARGIN, NET_Y, 5);

    // Kitchen (non-volley) lines
    g.lineStyle(2, 0xFFFFFF, 0.45);
    g.lineBetween(MARGIN, NET_Y - 65, W - MARGIN, NET_Y - 65);
    g.lineBetween(MARGIN, NET_Y + 65, W - MARGIN, NET_Y + 65);

    // Center service lines
    g.lineStyle(1, 0xFFFFFF, 0.35);
    g.lineBetween(W / 2, 45, W / 2, NET_Y - 65);
    g.lineBetween(W / 2, NET_Y + 65, W / 2, H - 45);

    // Floor shadow under net
    g.lineStyle(3, 0x000000, 0.2);
    g.lineBetween(MARGIN, NET_Y + 3, W - MARGIN, NET_Y + 3);
  }

  // ─── ENTITIES ──────────────────────────────────────────────────────────────

  createEntities() {
    const { W, H, NET_Y } = this;

    // Player body (circle with inner detail)
    this.playerGfx = this.add.graphics();
    this.playerX = W / 2;
    this.playerY = H * 0.74;
    this.drawPlayer();

    // Opponent body
    this.opponentGfx = this.add.graphics();
    this.oppX = W / 2;
    this.oppY = H * 0.26;
    this.drawOpponent();

    // Ball
    this.ballX = W / 2;
    this.ballY = NET_Y + 90;
    this.ballVX = 0;
    this.ballVY = 0;
    this.ballGfx = this.add.graphics();
    this.drawBall();

    // Hit zone ring (shown when canHit)
    this.hitRingGfx = this.add.graphics();
  }

  drawPlayer() {
    const g = this.playerGfx;
    g.clear();
    // Shadow
    g.fillStyle(0x000000, 0.3);
    g.fillEllipse(this.playerX, this.playerY + 18, 30, 10);
    // Body
    g.fillStyle(0x0088FF);
    g.fillCircle(this.playerX, this.playerY, 18);
    // Highlight
    g.fillStyle(0x44AAFF, 0.6);
    g.fillCircle(this.playerX - 5, this.playerY - 5, 8);
    // Paddle indicator
    const paddle = GAME_DATA.paddles.find(p => p.id === GameState.equippedPaddle) || GAME_DATA.paddles[0];
    g.fillStyle(paddle.color);
    g.fillRect(this.playerX + 10, this.playerY - 22, 8, 20);
  }

  drawOpponent() {
    const g = this.opponentGfx;
    g.clear();
    // Shadow
    g.fillStyle(0x000000, 0.3);
    g.fillEllipse(this.oppX, this.oppY + 18, 30, 10);
    // Body
    g.fillStyle(0xFF3333);
    g.fillCircle(this.oppX, this.oppY, 18);
    // Highlight
    g.fillStyle(0xFF7777, 0.6);
    g.fillCircle(this.oppX - 5, this.oppY - 5, 8);
    // Opponent paddle
    const paddle = GAME_DATA.paddles.find(p => p.id === this.opponentData.paddle) || GAME_DATA.paddles[0];
    g.fillStyle(paddle.color);
    g.fillRect(this.oppX - 18, this.oppY - 22, 8, 20);
  }

  drawBall() {
    const g = this.ballGfx;
    g.clear();
    if (!this.ballActive) return;
    // Shadow
    g.fillStyle(0x000000, 0.25);
    g.fillCircle(this.ballX + 2, this.ballY + 4, 8);
    // Ball
    g.fillStyle(0xFFFFFF);
    g.fillCircle(this.ballX, this.ballY, 9);
    // Shine
    g.fillStyle(0xFFFFFF, 0.8);
    g.fillCircle(this.ballX - 3, this.ballY - 3, 3);
    // Spin indicator
    if (this.ballSpin !== 0) {
      g.lineStyle(2, 0xFF8800, 0.8);
      g.strokeCircle(this.ballX, this.ballY, 11);
    }
  }

  // ─── JOYSTICK ──────────────────────────────────────────────────────────────

  createJoystick() {
    const { W, H } = this;
    this.jsBaseX = 80;
    this.jsBaseY = H - 100;
    this.jsRadius = 48;

    this.jsGfx = this.add.graphics();
    this.jsKnobGfx = this.add.graphics();
    this.drawJoystick(0, 0);

    this.js = { active: false, pointerId: null, dx: 0, dy: 0 };
  }

  drawJoystick(dx, dy) {
    const g = this.jsGfx;
    g.clear();
    g.lineStyle(2, 0xFFFFFF, 0.3);
    g.fillStyle(0x000000, 0.35);
    g.fillCircle(this.jsBaseX, this.jsBaseY, this.jsRadius);
    g.strokeCircle(this.jsBaseX, this.jsBaseY, this.jsRadius);

    const kg = this.jsKnobGfx;
    kg.clear();
    kg.fillStyle(0xFFFFFF, 0.7);
    kg.fillCircle(this.jsBaseX + dx, this.jsBaseY + dy, 20);
    kg.fillStyle(0xFFFFFF, 0.9);
    kg.fillCircle(this.jsBaseX + dx - 4, this.jsBaseY + dy - 4, 7);
  }

  // ─── INPUT ─────────────────────────────────────────────────────────────────

  setupInput() {
    this.swipe = { active: false, pointerId: null, startX: 0, startY: 0, startTime: 0 };

    this.input.on('pointerdown', ptr => this.onDown(ptr));
    this.input.on('pointermove', ptr => this.onMove(ptr));
    this.input.on('pointerup', ptr => this.onUp(ptr));
  }

  onDown(ptr) {
    if (this.gameOver) return;
    const dx = ptr.x - this.jsBaseX;
    const dy = ptr.y - this.jsBaseY;
    const distJs = Math.sqrt(dx * dx + dy * dy);

    if (distJs < this.jsRadius * 1.8 && !this.js.active) {
      this.js.active = true;
      this.js.pointerId = ptr.id;
      this.applyJoystick(ptr.x, ptr.y);
    } else if (!this.swipe.active) {
      this.swipe.active = true;
      this.swipe.pointerId = ptr.id;
      this.swipe.startX = ptr.x;
      this.swipe.startY = ptr.y;
      this.swipe.startTime = this.time.now;
    }
  }

  onMove(ptr) {
    if (ptr.id === this.js.pointerId && this.js.active) {
      this.applyJoystick(ptr.x, ptr.y);
    }
  }

  onUp(ptr) {
    if (ptr.id === this.js.pointerId) {
      this.js.active = false;
      this.js.dx = 0;
      this.js.dy = 0;
      this.drawJoystick(0, 0);
    }
    if (ptr.id === this.swipe.pointerId && this.swipe.active) {
      this.swipe.active = false;
      if (this.canHit) {
        const sdx = ptr.x - this.swipe.startX;
        const sdy = ptr.y - this.swipe.startY;
        const duration = this.time.now - this.swipe.startTime;
        this.executeHit(sdx, sdy, duration);
      }
    }
  }

  applyJoystick(px, py) {
    let dx = px - this.jsBaseX;
    let dy = py - this.jsBaseY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const clamped = Math.min(dist, this.jsRadius);
    const angle = Math.atan2(dy, dx);
    const nx = Math.cos(angle) * clamped;
    const ny = Math.sin(angle) * clamped;
    this.js.dx = nx / this.jsRadius;
    this.js.dy = ny / this.jsRadius;
    this.drawJoystick(nx, ny);
  }

  // ─── HIT MECHANICS ─────────────────────────────────────────────────────────

  executeHit(sdx, sdy, duration) {
    if (this.gameOver || !this.ballActive) return;
    const now = this.time.now;
    if (now - this.lastHitTime < this.hitCooldown) return;
    this.lastHitTime = now;

    const len = Math.sqrt(sdx * sdx + sdy * sdy);
    if (len < 8) { this.flashFeedback('TAP HIT!', '#FFFFFF', 1); return; }

    let nx = sdx / len;
    let ny = sdy / len;

    // Enforce upward direction (toward opponent)
    if (ny > -0.15) ny = -0.75;
    const renorm = Math.sqrt(nx * nx + ny * ny);
    nx /= renorm; ny /= renorm;

    // Base speed from power stat
    const paddle = GAME_DATA.paddles.find(p => p.id === GameState.equippedPaddle) || GAME_DATA.paddles[0];
    const baseSpeed = 380 + this.playerStats.power * 14 * paddle.power;

    // Timing bonus
    let bonus = 1.0;
    let bonusLabel = '';
    if (duration < 130) { bonus = 1.8; bonusLabel = '×1.8 PERFECT!'; }
    else if (duration < 230) { bonus = 1.5; bonusLabel = '×1.5 GREAT!'; }
    else if (duration < 380) { bonus = 1.2; bonusLabel = '×1.2 GOOD'; }

    // Faster Hit superpower
    if (this.activePowers.has('faster_hit')) {
      bonus *= 1.3;
      this.activePowers.delete('faster_hit');
    }

    // Spin Hit superpower
    this.ballSpin = this.activePowers.has('spin_hit') ? (Math.random() > 0.5 ? 1 : -1) : 0;
    if (this.ballSpin) this.activePowers.delete('spin_hit');

    // Accuracy-based deviation
    const acc = this.playerStats.accuracy * paddle.accuracy;
    const deviation = Math.max(0, (1 - acc / 45)) * 0.35;
    nx += (Math.random() - 0.5) * deviation;
    ny += (Math.random() - 0.5) * deviation * 0.4;
    const renorm2 = Math.sqrt(nx * nx + ny * ny);
    nx /= renorm2; ny /= renorm2;

    this.ballVX = nx * baseSpeed * bonus;
    this.ballVY = ny * baseSpeed * bonus;
    this.ballInPlayerZone = false;
    this.canHit = false;

    const color = bonus >= 1.8 ? '#FFD700' : bonus >= 1.5 ? '#00FF88' : bonus >= 1.2 ? '#88FFFF' : '#FFFFFF';
    this.flashFeedback(bonusLabel || 'HIT!', color, bonus);
  }

  flashFeedback(text, color, multiplier) {
    const t = this.add.text(this.W * 0.6, this.H * 0.62, text, {
      fontSize: multiplier >= 1.5 ? '26px' : '20px',
      fill: color, fontStyle: 'bold',
      stroke: '#000000', strokeThickness: 3,
    }).setOrigin(0.5);
    this.tweens.add({
      targets: t, y: t.y - 55, alpha: 0, duration: 900, ease: 'Power2',
      onComplete: () => t.destroy(),
    });
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  createUI() {
    const { W, H } = this;

    // Player HP bar
    this.add.text(10, 8, GameState.character.name || 'YOU', { fontSize: '11px', fill: '#88AAFF' });
    this.playerHPBg = this.add.rectangle(10, 22, 160, 13, 0x333333).setOrigin(0, 0.5);
    this.playerHPBar = this.add.rectangle(10, 22, 160, 13, 0x00FF44).setOrigin(0, 0.5);
    this.playerHPText = this.add.text(176, 22, `${this.playerHP}/${this.playerMaxHP}`, { fontSize: '10px', fill: '#FFFFFF' }).setOrigin(0, 0.5);

    // Opponent HP bar (top right)
    const oppName = this.opponentData.name;
    this.add.text(W - 10, 8, oppName, { fontSize: '11px', fill: '#FF8888' }).setOrigin(1, 0);
    this.oppHPBg = this.add.rectangle(W - 10, 22, 160, 13, 0x333333).setOrigin(1, 0.5);
    this.oppHPBar = this.add.rectangle(W - 10, 22, 160, 13, 0xFF3333).setOrigin(1, 0.5);
    this.oppHPText = this.add.text(W - 176, 22, `${this.opponentHP}/${this.opponentMaxHP}`, { fontSize: '10px', fill: '#FFFFFF' }).setOrigin(1, 0.5);

    // Mode label
    const modeLabel = this.mode === 'ranked' ? '⚡ RANKED' : '🏆 CAMPAIGN';
    this.add.text(W / 2, 15, modeLabel, { fontSize: '12px', fill: '#AAAAAA' }).setOrigin(0.5);

    // Superpower buttons (right side, above joystick)
    this.powerBtns = [];
    this.createPowerButtons();

    // Hint text
    this.hintText = this.add.text(W / 2, H - 22, 'Joystick: move  |  Swipe right: hit', {
      fontSize: '10px', fill: '#555555'
    }).setOrigin(0.5);
  }

  createPowerButtons() {
    const { W, H } = this;
    this.sessionPowers.slice(0, 3).forEach((powerId, i) => {
      const power = GAME_DATA.superpowers.find(p => p.id === powerId);
      if (!power) return;
      const x = W - 35 - i * 55;
      const y = H - 100;

      const circle = this.add.graphics();
      circle.fillStyle(power.color, 0.85);
      circle.fillCircle(x, y, 22);
      circle.lineStyle(2, 0xFFFFFF, 0.5);
      circle.strokeCircle(x, y, 22);

      const label = this.add.text(x, y, power.name.substring(0, 5), {
        fontSize: '9px', fill: '#FFFFFF', fontStyle: 'bold'
      }).setOrigin(0.5);

      // Invisible hit area
      const hitArea = this.add.circle(x, y, 22, 0xFFFFFF, 0).setInteractive({ useHandCursor: true });
      hitArea.on('pointerdown', () => {
        this.activatePower(powerId, i);
        circle.destroy();
        label.destroy();
        hitArea.destroy();
      });

      this.powerBtns.push({ powerId, circle, label, hitArea });
    });
  }

  activatePower(powerId) {
    const power = GAME_DATA.superpowers.find(p => p.id === powerId);
    if (!power) return;

    switch (powerId) {
      case 'faster_hit':
        this.activePowers.add('faster_hit');
        this.flashFeedback('Faster Hit READY!', '#00AAFF', 1);
        break;
      case 'dash':
        // Dash in joystick direction, or random
        const dir = this.js.dx !== 0 ? Math.sign(this.js.dx) : (Math.random() > 0.5 ? 1 : -1);
        this.playerX = Phaser.Math.Clamp(this.playerX + dir * 90, this.MARGIN + 20, this.W - this.MARGIN - 20);
        this.flashFeedback('DASH!', '#88FF00', 1);
        break;
      case 'slow_time':
        this.activePowers.add('slow_time');
        this.flashFeedback('SLOW TIME!', '#AA00FF', 1);
        this.time.delayedCall(power.duration, () => this.activePowers.delete('slow_time'));
        break;
      case 'spin_hit':
        this.activePowers.add('spin_hit');
        this.flashFeedback('Spin Ready!', '#FF8800', 1);
        break;
      case 'wingspan':
        this.activePowers.add('wingspan');
        this.flashFeedback('WINGSPAN!', '#00FFAA', 1);
        this.time.delayedCall(power.duration, () => this.activePowers.delete('wingspan'));
        break;
      case 'shield':
        this.shieldActive = true;
        this.flashFeedback('SHIELD UP!', '#FFFF00', 1);
        break;
    }
  }

  // ─── SERVE ─────────────────────────────────────────────────────────────────

  serveBall() {
    if (this.gameOver) return;
    this.ballX = this.W / 2 + (Math.random() - 0.5) * 60;
    this.ballY = this.playerServing ? this.H * 0.64 : this.H * 0.36;
    const speed = 260;
    const angle = this.playerServing
      ? -Math.PI / 2 + (Math.random() - 0.5) * 0.6
      : Math.PI / 2 + (Math.random() - 0.5) * 0.6;
    this.ballVX = Math.cos(angle) * speed;
    this.ballVY = Math.sin(angle) * speed;
    this.ballActive = true;
    this.ballInPlayerZone = this.playerServing;
    this.ballSpin = 0;
    this.canHit = false;

    if (this.hintText) this.hintText.setVisible(true);
  }

  // ─── UPDATE ────────────────────────────────────────────────────────────────

  update(time, delta) {
    if (this.gameOver) return;
    const dt = delta / 1000;

    this.movePlayer(dt);
    this.moveBall(dt);
    this.updateAI(dt);
    this.checkHitZone();
    this.updateHitRing();
    this.drawBall();
  }

  movePlayer(dt) {
    const speed = 100 + this.playerStats.moveSpeed * 3.8;
    this.playerX += this.js.dx * speed * dt;
    this.playerY += this.js.dy * speed * dt;
    this.playerX = Phaser.Math.Clamp(this.playerX, this.MARGIN + 20, this.W - this.MARGIN - 20);
    this.playerY = Phaser.Math.Clamp(this.playerY, this.NET_Y + 18, this.H - 50);
    this.drawPlayer();
  }

  moveBall(dt) {
    if (!this.ballActive) return;
    const slow = this.activePowers.has('slow_time') ? 0.38 : 1.0;

    this.ballX += this.ballVX * dt * slow;
    this.ballY += this.ballVY * dt * slow;

    // Spin drift (curves in air when heading to opponent)
    if (this.ballSpin !== 0 && this.ballVY < 0) {
      this.ballVX += this.ballSpin * 90 * dt;
    }

    // Wall bounces
    if (this.ballX < this.MARGIN + 10) {
      this.ballX = this.MARGIN + 10;
      this.ballVX = Math.abs(this.ballVX) * 0.92;
    }
    if (this.ballX > this.W - this.MARGIN - 10) {
      this.ballX = this.W - this.MARGIN - 10;
      this.ballVX = -Math.abs(this.ballVX) * 0.92;
    }

    // Track zone
    if (this.ballVY > 0 && this.ballY > this.NET_Y + 5) {
      this.ballInPlayerZone = true;
    } else if (this.ballVY < 0 && this.ballY < this.NET_Y - 5) {
      this.ballInPlayerZone = false;
    }

    // Scoring conditions
    if (this.ballY < 40) {
      this.playerScored();
    } else if (this.ballY > this.H - 40) {
      this.opponentScored();
    }

    // Net fault: ball going toward opponent side hits net from below
    // (simple check: if ball is at net height and moving up, let it pass)
    // Net fault when ball going DOWN hits net (bounced back)
    if (this.ballVY > 0 && Math.abs(this.ballY - this.NET_Y) < 7 && this.ballX > this.MARGIN && this.ballX < this.W - this.MARGIN) {
      // Ball bouncing into net from opponent side → player scores
      this.playerScored();
    }
  }

  checkHitZone() {
    if (!this.ballInPlayerZone || !this.ballActive) {
      this.canHit = false;
      return;
    }
    const dx = this.ballX - this.playerX;
    const dy = this.ballY - this.playerY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const radius = this.activePowers.has('wingspan') ? this.baseHitZone * 2 : this.baseHitZone;
    this.canHit = dist < radius;
  }

  updateHitRing() {
    const g = this.hitRingGfx;
    g.clear();
    if (!this.canHit) return;
    const radius = this.activePowers.has('wingspan') ? this.baseHitZone * 2 : this.baseHitZone;
    const pulse = 0.5 + 0.5 * Math.sin(this.time.now / 150);
    g.lineStyle(2, 0xFFFF00, 0.4 + pulse * 0.4);
    g.strokeCircle(this.playerX, this.playerY, radius);
    g.lineStyle(1, 0xFFFFFF, 0.2);
    g.strokeCircle(this.playerX, this.playerY, radius + 4);
  }

  // ─── AI ────────────────────────────────────────────────────────────────────

  updateAI(dt) {
    const { moveSpeed, power, accuracy } = this.opponentData.stats;
    const aiMoveSpeed = 75 + moveSpeed * 3.2;

    // Move toward ball x-position
    const targetX = this.ballX;
    if (Math.abs(this.oppX - targetX) > 4) {
      const dir = this.oppX < targetX ? 1 : -1;
      this.oppX += dir * aiMoveSpeed * dt;
      this.oppX = Phaser.Math.Clamp(this.oppX, this.MARGIN + 20, this.W - this.MARGIN - 20);
      this.drawOpponent();
    }

    // AI hit: ball in opponent zone and close enough
    if (!this.ballInPlayerZone && this.ballVY < 0 && this.ballActive && this.ballY < this.NET_Y - 5) {
      const dx = this.ballX - this.oppX;
      const dy = this.ballY - this.oppY;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const aiHitZone = 55 + accuracy * 1.8;

      if (dist < aiHitZone) {
        const aiBaseSpeed = 340 + power * 13;
        // Aim toward player zone with inaccuracy
        const inaccuracy = Math.max(0, 1 - accuracy / 40) * 120;
        const targetPX = this.playerX + (Math.random() - 0.5) * inaccuracy;
        const targetPY = this.H * 0.72;
        const tdx = targetPX - this.ballX;
        const tdy = targetPY - this.ballY;
        const tlen = Math.sqrt(tdx * tdx + tdy * tdy);
        this.ballVX = (tdx / tlen) * aiBaseSpeed;
        this.ballVY = (tdy / tlen) * aiBaseSpeed;
        this.ballInPlayerZone = false;
        this.ballSpin = 0;
        this.canHit = false;
      }
    }
  }

  // ─── SCORING ───────────────────────────────────────────────────────────────

  playerScored() {
    this.ballActive = false;
    this.canHit = false;
    const paddle = GAME_DATA.paddles.find(p => p.id === GameState.equippedPaddle) || GAME_DATA.paddles[0];
    const dmg = Math.round((10 + this.playerStats.power * 2.2) * paddle.power);
    this.opponentHP = Math.max(0, this.opponentHP - dmg);
    this.updateHPBars();
    this.showDamage(this.oppX, this.oppY, dmg, false);

    if (this.opponentHP <= 0) {
      this.endMatch(true);
    } else {
      this.playerServing = true;
      this.time.delayedCall(1100, () => this.serveBall());
    }
  }

  opponentScored() {
    this.ballActive = false;
    this.canHit = false;

    if (this.shieldActive) {
      this.shieldActive = false;
      this.showDamage(this.playerX, this.playerY, 0, true, 'SHIELD!');
      this.playerServing = false;
      this.time.delayedCall(1100, () => this.serveBall());
      return;
    }

    const dmg = Math.round(10 + this.opponentData.stats.power * 2.2);
    this.playerHP = Math.max(0, this.playerHP - dmg);
    this.updateHPBars();
    this.showDamage(this.playerX, this.playerY, dmg, true);

    if (this.playerHP <= 0) {
      this.endMatch(false);
    } else {
      this.playerServing = false;
      this.time.delayedCall(1100, () => this.serveBall());
    }
  }

  showDamage(x, y, amount, isPlayer, overrideText) {
    const text = overrideText || (amount > 0 ? `-${amount} HP` : '0');
    const color = isPlayer ? '#FF4444' : '#FF8800';
    const t = this.add.text(x, y - 10, text, {
      fontSize: '20px', fill: color, fontStyle: 'bold',
      stroke: '#000000', strokeThickness: 3,
    }).setOrigin(0.5);
    this.tweens.add({
      targets: t, y: y - 65, alpha: 0, duration: 1000, ease: 'Power2',
      onComplete: () => t.destroy(),
    });
  }

  updateHPBars() {
    const pPct = this.playerHP / this.playerMaxHP;
    this.playerHPBar.width = 160 * pPct;
    this.playerHPBar.setFillStyle(pPct > 0.5 ? 0x00FF44 : pPct > 0.25 ? 0xFFAA00 : 0xFF2222);
    this.playerHPText.setText(`${this.playerHP}/${this.playerMaxHP}`);

    const oPct = this.opponentHP / this.opponentMaxHP;
    this.oppHPBar.width = 160 * oPct;
    this.oppHPBar.setFillStyle(oPct > 0.5 ? 0xFF3333 : oPct > 0.25 ? 0xFF8800 : 0xFF2222);
    this.oppHPText.setText(`${this.opponentHP}/${this.opponentMaxHP}`);
  }

  // ─── END MATCH ─────────────────────────────────────────────────────────────

  endMatch(playerWon) {
    this.gameOver = true;
    this.ballActive = false;
    if (this.hintText) this.hintText.setVisible(false);

    const W = this.W, H = this.H;
    this.add.rectangle(W / 2, H / 2, W, H, 0x000000, 0.72);

    const resultText = playerWon ? 'VICTORY!' : 'DEFEATED';
    const resultColor = playerWon ? '#FFD700' : '#FF4444';

    this.add.text(W / 2, H / 2 - 90, resultText, {
      fontSize: '46px', fill: resultColor, fontStyle: 'bold',
      stroke: '#000000', strokeThickness: 5,
    }).setOrigin(0.5);

    const oppPaddle = GAME_DATA.paddles.find(p => p.id === this.opponentData.name) || GAME_DATA.paddles[0];

    if (playerWon) {
      const xpGain = 40 + this.opponentData.level * 18;
      GameState.addXP(xpGain);

      // Determine loot orb rarity
      const roll = Math.random();
      const orbType = roll < 0.08 ? 'gold' : roll < 0.32 ? 'silver' : 'bronze';

      this.add.text(W / 2, H / 2 - 40, `+${xpGain} XP  ·  Level ${GameState.level}`, {
        fontSize: '18px', fill: '#FFD700',
      }).setOrigin(0.5);

      this.add.text(W / 2, H / 2 - 10, `Loot Orb: ${orbType.toUpperCase()}`, {
        fontSize: '15px', fill: orbType === 'gold' ? '#FFD700' : orbType === 'silver' ? '#C0C0C0' : '#CD7F32',
      }).setOrigin(0.5);

      // Advance campaign
      if (this.mode === 'campaign' && this.levelIndex >= GameState.campaignProgress) {
        GameState.campaignProgress = this.levelIndex + 1;
        GameState.save();
      }

      const lootBtn = this.add.text(W / 2, H / 2 + 50, '🎁 OPEN LOOT', {
        fontSize: '22px', fill: '#FFFFFF', fontStyle: 'bold',
        backgroundColor: '#335500', padding: { x: 18, y: 10 },
      }).setOrigin(0.5).setInteractive({ useHandCursor: true });
      lootBtn.on('pointerdown', () => {
        this.scene.start('LootScene', { orbType, mode: this.mode, levelIndex: this.levelIndex });
      });

    } else {
      this.add.text(W / 2, H / 2 - 35, 'Better luck next time!', {
        fontSize: '16px', fill: '#AAAAAA',
      }).setOrigin(0.5);

      const retryBtn = this.add.text(W / 2, H / 2 + 50, '↺ RETRY', {
        fontSize: '22px', fill: '#FFFFFF', fontStyle: 'bold',
        backgroundColor: '#550000', padding: { x: 18, y: 10 },
      }).setOrigin(0.5).setInteractive({ useHandCursor: true });
      retryBtn.on('pointerdown', () => {
        this.scene.start('GameScene', { opponent: this.opponentData, mode: this.mode, levelIndex: this.levelIndex });
      });
    }

    const menuBtn = this.add.text(W / 2, H / 2 + 115, '← Main Menu', {
      fontSize: '16px', fill: '#AAAAAA', padding: { x: 12, y: 6 },
    }).setOrigin(0.5).setInteractive({ useHandCursor: true });
    menuBtn.on('pointerdown', () => this.scene.start('MainMenuScene'));
  }
}
