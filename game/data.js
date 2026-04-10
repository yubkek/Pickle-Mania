/* eslint-disable no-unused-vars */
'use strict';

const GAME_DATA = {
  paddles: [
    { id: 'wooden',    name: 'Wooden Paddle',   rarity: 'C', power: 1.0, accuracy: 1.0, color: 0x8B4513, desc: 'A humble beginning.'        },
    { id: 'carbon',    name: 'Carbon Fiber',     rarity: 'C', power: 1.1, accuracy: 1.1, color: 0x555555, desc: 'Light and responsive.'       },
    { id: 'thunder',   name: 'Thunderbolt',      rarity: 'C', power: 1.2, accuracy: 0.9, color: 0xFFAA00, desc: 'Raw power, less precision.'  },
    { id: 'lightning', name: 'Lightning Strike', rarity: 'B', power: 1.3, accuracy: 1.0, color: 0x00AAFF, desc: 'Speed meets power.'          },
    { id: 'precision', name: 'Precision Pro',    rarity: 'B', power: 1.0, accuracy: 1.5, color: 0x00FF88, desc: 'Every shot counts.'          },
    { id: 'storm',     name: 'Storm Chaser',     rarity: 'B', power: 1.25,accuracy: 1.2, color: 0x8800FF, desc: 'Unpredictable and fierce.'   },
    { id: 'dragon',    name: 'Dragon Scale',     rarity: 'A', power: 1.5, accuracy: 1.2, color: 0xFF4400, desc: 'Forged in dragon fire.'      },
    { id: 'phoenix',   name: 'Phoenix Wing',     rarity: 'A', power: 1.4, accuracy: 1.4, color: 0xFF8800, desc: 'Rises above all others.'    },
    { id: 'cosmos',    name: 'Cosmos',           rarity: 'A', power: 1.6, accuracy: 1.3, color: 0xFF00FF, desc: 'Beyond the stars.'          },
  ],

  superpowers: [
    { id: 'faster_hit', name: 'Faster Hit',   rarity: 'B', color: 0x00AAFF, desc: 'Next hit travels 30% faster.',            duration: 0     },
    { id: 'dash',       name: 'Side Dash',    rarity: 'C', color: 0x88FF00, desc: 'Instantly dash left or right.',           cooldown: 8000  },
    { id: 'slow_time',  name: 'Slow Time',    rarity: 'B', color: 0xAA00FF, desc: 'Slows enemy time for 3 seconds.',         duration: 3000  },
    { id: 'spin_hit',   name: 'Spin Hit',     rarity: 'A', color: 0xFF8800, desc: 'Ball curves unpredictably on landing.',   duration: 0     },
    { id: 'wingspan',   name: 'Wingspan',     rarity: 'C', color: 0x00FFAA, desc: 'Hit zone doubled for 8 seconds.',         duration: 8000  },
    { id: 'shield',     name: 'Shield',       rarity: 'C', color: 0xFFFF00, desc: 'Block the next damage taken.',            duration: 0     },
  ],

  lootTables: {
    bronze: { rarityWeights: { C: 0.80, B: 0.18, A: 0.02 } },
    silver: { rarityWeights: { C: 0.55, B: 0.35, A: 0.10 } },
    gold:   { rarityWeights: { C: 0.25, B: 0.45, A: 0.30 } },
  },

  presetCharacters: [
    { name: 'Speedster',     moveSpeed: 20, power: 5,  health: 10, accuracy: 15 },
    { name: 'Tank',          moveSpeed: 5,  power: 20, health: 20, accuracy: 5  },
    { name: 'Sharpshooter',  moveSpeed: 10, power: 10, health: 10, accuracy: 20 },
    { name: 'Balanced',      moveSpeed: 13, power: 12, health: 13, accuracy: 12 },
  ],

  campaignOpponents: [
    { name: 'Rookie Randy', level: 1,  stats: { moveSpeed: 8,  power: 8,  health: 15, accuracy: 8  }, paddle: 'wooden'    },
    { name: 'Club Casey',   level: 3,  stats: { moveSpeed: 12, power: 12, health: 18, accuracy: 12 }, paddle: 'carbon'    },
    { name: 'Pro Pete',     level: 5,  stats: { moveSpeed: 16, power: 16, health: 20, accuracy: 16 }, paddle: 'lightning' },
    { name: 'Elite Elena',  level: 8,  stats: { moveSpeed: 20, power: 20, health: 22, accuracy: 20 }, paddle: 'precision' },
    { name: 'Champion Rex', level: 12, stats: { moveSpeed: 24, power: 24, health: 26, accuracy: 22 }, paddle: 'dragon'    },
  ],

  rarityColors: { C: '#888888', B: '#0088FF', A: '#FF8800' },
  rarityNames:  { C: 'Common', B: 'Rare', A: 'Legendary' },

  xpThresholds: [0, 100, 250, 500, 900, 1400, 2100, 3000, 4200, 6000, 9999999],
  rankUnlockLevel: 5,
};
