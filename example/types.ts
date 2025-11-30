
export enum GameState {
  PLAYING = 'PLAYING',
  GAME_OVER = 'GAME_OVER',
  LOOT_MODAL = 'LOOT_MODAL',
  LEVEL_COMPLETE = 'LEVEL_COMPLETE'
}

export type EquipmentSlot = 'WEAPON' | 'ACCESSORY' | 'HELMET' | 'ARMOR' | 'PANTS' | 'GLOVES' | 'BOOTS';

export interface Equipment {
  id: string;
  name: string;
  type: EquipmentSlot;
  statBoost: number;
  description: string;
}

export interface PlayerStats {
  lives: number;
  level: number;
  xp: number;
  maxXp: number;
  hp: number;
  maxHp: number;
  attack: number; // Base attack
  equipment: {
    WEAPON?: Equipment;
    ACCESSORY?: Equipment;
    HELMET?: Equipment;
    ARMOR?: Equipment;
    PANTS?: Equipment;
    GLOVES?: Equipment;
    BOOTS?: Equipment;
  };
}

// Physics Types
export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export type EnemyVariant = 'BLOB' | 'CRAB' | 'EYE';

export interface Entity extends Rect {
  id: string;
  vx: number;
  vy: number;
  type: 'PLAYER' | 'ENEMY' | 'PARTICLE';
  isDead?: boolean;
  
  // Stats
  hp?: number;
  maxHp?: number;
  isBoss?: boolean;

  // Enemy specific
  variant?: EnemyVariant;
  patrolStart?: number;
  patrolEnd?: number;
  facing?: number; // 1 or -1
  
  // Respawn & Loot logic
  originalX?: number;
  originalY?: number;
  respawnTime?: number; // Timestamp when enemy comes back to life
  isLooted?: boolean;
}

export interface Particle extends Entity {
  life: number;
  color: string;
}

export interface GeneratedLootData {
  name: string;
  type: EquipmentSlot | 'LIFE';
  statBoost: number;
  description: string;
}

export interface GeneratedEnemyData {
  name: string;
  description: string;
  maxHp: number;
  attack: number;
  defense: number;
  isBoss: boolean;
  visualPrompt: string;
}

export enum CharacterType {
  HERO = 'HERO',
  ENEMY = 'ENEMY'
}

export interface Character {
  id: string;
  name: string;
  imageUrl: string;
  level: number;
  currentHp: number;
  maxHp: number;
  xp: number;
  maxXp: number;
  attack: number;
  defense: number;
  weapon?: Equipment;
  accessory?: Equipment;
}

export interface LogEntry {
  id: string;
  type: 'damage' | 'heal' | 'critical' | 'info';
  message: string;
}
