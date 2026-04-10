'use strict';

const GameState = (() => {
  const SAVE_KEY = 'pickle_mania_save';

  const defaults = () => ({
    created: false,
    character: { moveSpeed: 13, power: 12, health: 13, accuracy: 12, name: 'Player' },
    level: 1,
    xp: 0,
    campaignProgress: 0,
    equippedPaddle: 'wooden',
    equippedPowers: [],
    inventory: [
      { type: 'paddle', id: 'wooden' }
    ],
  });

  let _state = defaults();

  function load() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        _state = Object.assign(defaults(), parsed);
      }
    } catch (e) {
      console.warn('Failed to load save:', e);
      _state = defaults();
    }
  }

  function save() {
    try {
      localStorage.setItem(SAVE_KEY, JSON.stringify(_state));
    } catch (e) {
      console.warn('Failed to save:', e);
    }
  }

  function reset() {
    _state = defaults();
    save();
  }

  function addXP(amount) {
    _state.xp += amount;
    const thresholds = GAME_DATA.xpThresholds;
    while (_state.level < thresholds.length - 1 && _state.xp >= thresholds[_state.level]) {
      _state.level += 1;
    }
    save();
  }

  function addToInventory(type, id) {
    // Allow duplicates (collect multiples)
    _state.inventory.push({ type, id });
    save();
  }

  function hasItem(type, id) {
    return _state.inventory.some(i => i.type === type && i.id === id);
  }

  function xpForNextLevel() {
    const thresholds = GAME_DATA.xpThresholds;
    if (_state.level >= thresholds.length - 1) return 0;
    return thresholds[_state.level];
  }

  function xpProgress() {
    const thresholds = GAME_DATA.xpThresholds;
    const prevThreshold = thresholds[_state.level - 1] || 0;
    const nextThreshold = thresholds[_state.level] || prevThreshold + 1;
    return (_state.xp - prevThreshold) / (nextThreshold - prevThreshold);
  }

  // Proxy the internal state for direct property access
  const proxy = new Proxy({}, {
    get(_, key) {
      if (key === 'load') return load;
      if (key === 'save') return save;
      if (key === 'reset') return reset;
      if (key === 'addXP') return addXP;
      if (key === 'addToInventory') return addToInventory;
      if (key === 'hasItem') return hasItem;
      if (key === 'xpForNextLevel') return xpForNextLevel;
      if (key === 'xpProgress') return xpProgress;
      return _state[key];
    },
    set(_, key, value) {
      _state[key] = value;
      return true;
    }
  });

  load();
  return proxy;
})();
