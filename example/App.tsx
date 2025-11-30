
import React, { useEffect, useRef, useState, useCallback } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { GameState, PlayerStats, Entity, Rect, Particle, EquipmentSlot, GeneratedLootData, EnemyVariant } from './types';
import { generateLoot, generateFastLoot } from './services/geminiService';
import { HUD } from './components/HUD';

// --- Constants ---
const TILE_SIZE = 48;
const GRAVITY = 0.65;
const JUMP_FORCE = -14; 
const MOVE_SPEED = 6;
const FRICTION = 0.85;
const ENEMY_SPEED_BASE = 2;
const LEVEL_WIDTH_BASE = 150; 
const LEVEL_HEIGHT = 12; // 12 tiles high
const RESPAWN_TIME_MS = 30000; // 30 seconds
const LEVELS_PER_WORLD = 13;
const INITIAL_LIVES = 3;

// --- Theme Config ---
interface WorldTheme {
  name: string;
  sky: [string, string];
  ground: string;
  groundDark: string;
  grass: string;
  grassHighlight: string;
  brick: string;
  brickDark: string;
  enemyVariant: EnemyVariant;
}

const WORLD_THEMES: Record<number, WorldTheme> = {
  1: {
    name: "SLIME PLAINS",
    sky: ['#4facfe', '#00f2fe'], // Bright Cyan Blue gradient
    ground: '#e67e22', // Carrot Orange
    groundDark: '#d35400',
    grass: '#2ecc71', // Emerald Green
    grassHighlight: '#a9dfbf',
    brick: '#cd6133',
    brickDark: '#a0400b',
    enemyVariant: 'BLOB'
  },
  2: {
    name: "SCORCHED DESERT",
    sky: ['#f12711', '#f5af19'], // Red to Yellow sunset
    ground: '#f1c40f', // Sand Yellow
    groundDark: '#d4ac0d',
    grass: '#f39c12', // Dry Grass
    grassHighlight: '#f7dc6f',
    brick: '#ba4a00',
    brickDark: '#873600',
    enemyVariant: 'CRAB'
  },
  3: {
    name: "WATCHER'S VALLEY",
    sky: ['#2c3e50', '#000000'], // Dark Night
    ground: '#7f8c8d', // Grey Stone
    groundDark: '#2c3e50',
    grass: '#8e44ad', // Purple Corrupted Grass
    grassHighlight: '#9b59b6',
    brick: '#34495e',
    brickDark: '#2c3e50',
    enemyVariant: 'EYE'
  }
};

const getTheme = (worldNum: number): WorldTheme => {
  const normalizedWorld = ((worldNum - 1) % 3) + 1;
  return WORLD_THEMES[normalizedWorld];
};

// --- Procedural Assets helpers ---
const drawRoundedRect = (ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) => {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
  ctx.fill();
};

const drawCircle = (ctx: CanvasRenderingContext2D, x: number, y: number, r: number, color: string) => {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fill();
};

interface FloatingText {
  id: string;
  x: number;
  y: number;
  text: string;
  life: number;
  color: string;
  vy: number;
}

const App: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  
  // -- Refs for Logic (Avoids Stale Closures) --
  const statsRef = useRef<PlayerStats>({
    lives: INITIAL_LIVES, level: 1, xp: 0, maxXp: 300, hp: 3, maxHp: 3, attack: 1, equipment: {}
  });

  // -- React State for UI Sync --
  const [gameState, setGameState] = useState<GameState>(GameState.PLAYING);
  const [stage, setStage] = useState(1);
  const [uiStats, setUiStats] = useState<PlayerStats>(statsRef.current);
  const [autoLoot, setAutoLoot] = useState(false);
  
  const [foundLoot, setFoundLoot] = useState<GeneratedLootData | null>(null);
  const [isLoadingLoot, setIsLoadingLoot] = useState(false);
  const [lootTargetId, setLootTargetId] = useState<string | null>(null);

  // -- Game Entities Refs --
  const playerRef = useRef<Entity>({ id: 'p1', type: 'PLAYER', x: 100, y: 100, w: 32, h: 44, vx: 0, vy: 0, facing: 1 });
  const enemiesRef = useRef<Entity[]>([]);
  const particlesRef = useRef<Particle[]>([]);
  const floatingTextsRef = useRef<FloatingText[]>([]);
  const keysRef = useRef<{ [key: string]: boolean }>({});
  const gameLoopRef = useRef<number>(0);
  const mapRef = useRef<number[][]>([]);
  const cameraRef = useRef({ x: 0, y: 0 });
  const frameRef = useRef(0);

  // --- Helper: Sync Stats ---
  const syncStats = () => {
    setUiStats({ ...statsRef.current });
  };

  const addFloatingText = (x: number, y: number, text: string, color: string = 'white') => {
    floatingTextsRef.current.push({
      id: uuidv4(),
      x, y, text, color,
      life: 1.0,
      vy: -2
    });
  };

  // --- Level Generation ---
  const generateLevel = useCallback(() => {
    const worldNum = Math.ceil(stage / LEVELS_PER_WORLD);
    const subStage = (stage - 1) % LEVELS_PER_WORLD + 1;
    const theme = getTheme(worldNum);
    
    // Boss Level Logic
    const isBossLevel = subStage === LEVELS_PER_WORLD;
    
    const levelWidth = isBossLevel ? 60 : LEVEL_WIDTH_BASE + (subStage * 10);
    // Pit chance scales, but we handle it via safe path algorithm. No pits on boss level.
    const pitFrequency = isBossLevel ? 0 : 0.1 + (subStage * 0.03); 
    const enemyDensity = isBossLevel ? 0 : 10 - (subStage * 0.5); 

    const map: number[][] = [];
    const enemies: Entity[] = [];

    // Initialize empty air
    for (let y = 0; y < LEVEL_HEIGHT; y++) {
      const row = new Array(levelWidth).fill(0);
      map.push(row);
    }

    // --- Safe Path Terrain Generation ---
    let x = 0;
    let justDidPit = false;

    while (x < levelWidth) {
      // 1. Safe Start Zone (FIX: Ensures player doesn't fall through world on spawn)
      if (x < 15) {
        map[LEVEL_HEIGHT - 1][x] = 1;
        map[LEVEL_HEIGHT - 2][x] = 1;
        x++;
        continue;
      }

      // Safe End Zone
      if (x > levelWidth - 20) {
        map[LEVEL_HEIGHT - 1][x] = 1;
        map[LEVEL_HEIGHT - 2][x] = 1;
        x++;
        continue;
      }

      // 2. Decision: Pit or Ground?
      const makePit = !justDidPit && Math.random() < pitFrequency;

      if (makePit) {
        // --- Create Pit ---
        const pitLength = 2 + Math.floor(Math.random() * 2); // 2 or 3 tiles
        x += pitLength;
        justDidPit = true;
      } else {
        // --- Create Ground ---
        const minGround = justDidPit ? 4 : 1; 
        const segmentLength = Math.max(minGround, 1 + Math.floor(Math.random() * 4));

        for (let i = 0; i < segmentLength; i++) {
          if (x >= levelWidth - 20) break; 

          // Standard Ground
          map[LEVEL_HEIGHT - 1][x] = 1;
          map[LEVEL_HEIGHT - 2][x] = 1;

          // -- Features (Platforms / Walls) --
          if (!justDidPit || i > 1) {
             const featureRoll = Math.random();
             
             // PLATFORM
             if (!isBossLevel && featureRoll > 0.8) {
               const h = 4 + Math.floor(Math.random() * 2); // 4 or 5
               const py = LEVEL_HEIGHT - h;
               map[py][x] = 1;
               
               if (x + 1 < levelWidth && Math.random() > 0.5) {
                 map[py][x+1] = 1;
               }

               if (Math.random() > 0.7) {
                 enemies.push({
                    id: uuidv4(), type: 'ENEMY',
                    x: x * TILE_SIZE, y: (py - 1) * TILE_SIZE,
                    originalX: x * TILE_SIZE, originalY: (py - 1) * TILE_SIZE,
                    w: 32, h: 32, vx: ENEMY_SPEED_BASE, vy: 0, facing: -1, 
                    isDead: false, isLooted: false, variant: theme.enemyVariant,
                    hp: 1, maxHp: 1, isBoss: false
                 });
               }
             }
             // PIPE / WALL
             else if (!isBossLevel && featureRoll > 0.96) {
               map[LEVEL_HEIGHT - 3][x] = 2; // 2 = BRICK/BLOCK
               map[LEVEL_HEIGHT - 4][x] = 2;
             }
          }
          x++;
        }
        justDidPit = false;
      }
    }

    // Walls at world edges
    for (let y = 0; y < LEVEL_HEIGHT; y++) {
      map[y][0] = 1;
      map[y][levelWidth - 1] = 1;
    }

    // Flagpole Base
    const endX = levelWidth - 5;
    map[LEVEL_HEIGHT - 3][endX] = 1;

    // --- BOSS SPAWN ---
    if (isBossLevel) {
      const bossX = (levelWidth - 15) * TILE_SIZE;
      const bossY = (LEVEL_HEIGHT - 3) * TILE_SIZE - 32; // A bit higher
      const bossHp = 3 + Math.floor(worldNum);
      
      enemies.push({
        id: uuidv4(), type: 'ENEMY',
        x: bossX, y: bossY,
        originalX: bossX, originalY: bossY,
        w: 64, h: 64, // Big Boss
        vx: -ENEMY_SPEED_BASE * 1.5, vy: 0, facing: -1, 
        isDead: false, isLooted: false, variant: theme.enemyVariant,
        hp: bossHp, maxHp: bossHp, isBoss: true
      });
      
      addFloatingText(100, 100, "CHEFE CHEGOU!", "#FF0000");
    } else {
      // --- Standard Enemies Spawn Pass ---
      const enemySpacing = Math.max(8, enemyDensity); 
      for (let ex = 20; ex < levelWidth - 25; ex += enemySpacing) {
         if (map[LEVEL_HEIGHT - 2][ex] === 1 && map[LEVEL_HEIGHT - 3][ex] === 0) {
            if (Math.random() > 0.3) {
               enemies.push({
                  id: uuidv4(), type: 'ENEMY',
                  x: ex * TILE_SIZE, y: (LEVEL_HEIGHT - 3) * TILE_SIZE,
                  originalX: ex * TILE_SIZE, originalY: (LEVEL_HEIGHT - 3) * TILE_SIZE,
                  w: 32, h: 32, vx: -ENEMY_SPEED_BASE, vy: 0, facing: -1, 
                  isDead: false, isLooted: false, variant: theme.enemyVariant,
                  hp: 1, maxHp: 1, isBoss: false
               });
            }
         }
      }
    }

    mapRef.current = map;
    enemiesRef.current = enemies;
    
    // FIX: Explicitly reset Physics to prevent floating bug
    playerRef.current.x = 100;
    playerRef.current.y = 100;
    playerRef.current.vx = 0;
    playerRef.current.vy = 0;
    cameraRef.current.x = 0;
  }, [stage]);

  // Handle Complete Game Reset
  const fullReset = () => {
    setStage(1);
    statsRef.current = {
      lives: INITIAL_LIVES, 
      level: 1, 
      xp: 0, 
      maxXp: 300, 
      hp: 3, 
      maxHp: 3, 
      attack: 1, 
      equipment: {}
    };
    initGame();
  };

  const initGame = useCallback(() => {
    generateLevel();
    particlesRef.current = [];
    floatingTextsRef.current = [];
    setGameState(GameState.PLAYING);
    // Ensure HP is full on level start
    statsRef.current.hp = statsRef.current.maxHp;
    syncStats();
  }, [generateLevel]);

  // Restart logic for new stage
  const nextStage = () => {
     setStage(s => s + 1);
     initGame();
  };

  useEffect(() => {
    initGame();
  }, [initGame]);

  // --- Physics Helpers ---
  const checkCollision = (rect1: Rect, rect2: Rect) => {
    return (
      rect1.x < rect2.x + rect2.w &&
      rect1.x + rect1.w > rect2.x &&
      rect1.y < rect2.y + rect2.h &&
      rect1.y + rect1.h > rect2.y
    );
  };

  const getTileAt = (x: number, y: number) => {
    const mapY = Math.floor(y / TILE_SIZE);
    const mapX = Math.floor(x / TILE_SIZE);
    if (mapY < 0 || mapY >= mapRef.current.length || mapX < 0 || mapX >= mapRef.current[0].length) {
      return 0; // Treat out of bounds as Air
    }
    return mapRef.current[mapY][mapX] > 0 ? 1 : 0;
  };
  
  // Specific check for brick drawing
  const getRawTileAt = (x: number, y: number) => {
    const mapY = Math.floor(y / TILE_SIZE);
    const mapX = Math.floor(x / TILE_SIZE);
    if (mapY < 0 || mapY >= mapRef.current.length || mapX < 0 || mapX >= mapRef.current[0].length) {
      return 0; 
    }
    return mapRef.current[mapY][mapX];
  };

  const spawnParticles = (x: number, y: number, color: string, count: number) => {
    for (let i = 0; i < count; i++) {
      particlesRef.current.push({
        id: uuidv4(),
        type: 'PARTICLE',
        x, y, w: 6, h: 6,
        vx: (Math.random() - 0.5) * 12,
        vy: (Math.random() - 0.5) * 12,
        life: 1.0,
        color
      });
    }
  };

  const handlePlayerDeath = () => {
    const stats = statsRef.current;
    
    if (stats.lives > 1) {
      // LOSE A LIFE
      stats.lives -= 1;
      stats.hp = stats.maxHp; // Heal
      
      // Item Loss Penalty
      const slots: EquipmentSlot[] = ['BOOTS', 'ACCESSORY', 'HELMET', 'ARMOR', 'PANTS', 'GLOVES'];
      const equippedSlots = slots.filter(s => stats.equipment[s]);
      
      if (equippedSlots.length > 0) {
        const slotToLose = equippedSlots[Math.floor(Math.random() * equippedSlots.length)];
        const lostItemName = stats.equipment[slotToLose]?.name;
        stats.equipment[slotToLose] = undefined;
        setTimeout(() => addFloatingText(playerRef.current.x, playerRef.current.y - 40, `PERDEU ${lostItemName}!`, "#FF0000"), 500);
      }

      // Respawn at start
      playerRef.current.x = 100;
      playerRef.current.y = 100;
      playerRef.current.vx = 0;
      playerRef.current.vy = 0;
      cameraRef.current.x = 0;
      
      addFloatingText(100, 100, `${stats.lives} VIDAS!`, "#FFFFFF");
      syncStats();
    } else {
      // GAME OVER (Final Death)
      stats.lives = 0;
      syncStats();
      setGameState(GameState.GAME_OVER);
    }
  };

  // --- Main Update Loop ---
  const update = () => {
    if (gameState !== GameState.PLAYING) return;
    frameRef.current++;

    const player = playerRef.current;
    const stats = statsRef.current; // Access latest stats
    const mapWidthPixels = mapRef.current[0].length * TILE_SIZE;
    
    // 1. Controls
    if (keysRef.current['ArrowRight']) {
       player.vx += 0.8;
       player.facing = 1;
    }
    if (keysRef.current['ArrowLeft']) {
       player.vx -= 0.8;
       player.facing = -1;
    }
    if (Math.abs(player.vx) > MOVE_SPEED) player.vx = player.facing! * MOVE_SPEED;

    // Jump
    if ((keysRef.current['ArrowUp'] || keysRef.current[' ']) && player.vy === 0) {
      const bottomY = player.y + player.h;
      if (getTileAt(player.x + 4, bottomY + 2) === 1 || getTileAt(player.x + player.w - 4, bottomY + 2) === 1) {
        player.vy = JUMP_FORCE;
        // Boots give small jump boost
        if (stats.equipment.BOOTS) player.vy -= 1; 
      }
    }

    player.vx *= FRICTION;
    player.vy += GRAVITY;

    // 2. Player X Collision
    player.x += player.vx;
    if (getTileAt(player.x, player.y) === 1 || getTileAt(player.x + player.w, player.y) === 1 ||
        getTileAt(player.x, player.y + player.h - 2) === 1 || getTileAt(player.x + player.w, player.y + player.h - 2) === 1) {
      player.x -= player.vx;
      player.vx = 0;
    }

    // 3. Player Y Collision
    player.y += player.vy;
    if (player.vy > 0) { 
      if (getTileAt(player.x + 4, player.y + player.h) === 1 || getTileAt(player.x + player.w - 4, player.y + player.h) === 1) {
        player.y = Math.floor(player.y / TILE_SIZE) * TILE_SIZE + (TILE_SIZE - player.h);
        player.vy = 0;
      }
    } else if (player.vy < 0) { 
      if (getTileAt(player.x + 4, player.y) === 1 || getTileAt(player.x + player.w - 4, player.y) === 1) {
        player.y = (Math.floor(player.y / TILE_SIZE) + 1) * TILE_SIZE;
        player.vy = 0;
      }
    }

    // Death Pit
    if (player.y > LEVEL_HEIGHT * TILE_SIZE + 100) {
       handlePlayerDeath();
    }

    // Flagpole Win Condition
    const flagpoleX = (mapRef.current[0].length - 5) * TILE_SIZE;
    if (player.x >= flagpoleX) {
       setGameState(GameState.LEVEL_COMPLETE);
       setTimeout(nextStage, 4000);
    }

    // 4. Camera Follow
    const canvasWidth = canvasRef.current?.width || 800;
    const targetCamX = player.x - canvasWidth / 2 + player.w / 2;
    cameraRef.current.x += (targetCamX - cameraRef.current.x) * 0.1;
    cameraRef.current.x = Math.max(0, Math.min(cameraRef.current.x, mapWidthPixels - canvasWidth));

    // 5. Enemies and Looting
    let nearbyLootId: string | null = null;
    const currentTime = Date.now();
    let didStatsChange = false;

    enemiesRef.current.forEach(enemy => {
      if (Math.abs(enemy.x - player.x) > 1000) return;

      // Respawn Check
      if (enemy.isDead) {
        if (enemy.respawnTime && currentTime > enemy.respawnTime) {
          enemy.isDead = false;
          enemy.isLooted = false;
          enemy.hp = enemy.maxHp; // Heal enemy on respawn
          enemy.x = enemy.originalX || enemy.x;
          enemy.y = enemy.originalY || enemy.y;
          enemy.vx = (ENEMY_SPEED_BASE + (stage % 10)*0.1) * (Math.random() > 0.5 ? 1 : -1);
          enemy.vy = 0;
          spawnParticles(enemy.x + enemy.w/2, enemy.y + enemy.h/2, '#88FF88', 12); 
        } else {
          // --- AUTO LOOT LOGIC ---
          if (!enemy.isLooted && checkCollision(player, enemy)) {
             if (autoLoot && !enemy.isBoss) {
                // INSTANT AUTO LOOT for Mobs
                const loot = generateFastLoot(statsRef.current.level);
                enemy.isLooted = true;
                
                // Smart Compare
                let shouldEquip = false;
                if (loot.type === 'LIFE') {
                  shouldEquip = true;
                } else {
                  const current = statsRef.current.equipment[loot.type as EquipmentSlot];
                  if (!current || loot.statBoost > current.statBoost) {
                    shouldEquip = true;
                  }
                }

                if (shouldEquip) {
                   if (loot.type === 'LIFE') {
                      statsRef.current.lives++;
                      addFloatingText(player.x, player.y - 20, "AUTO: 1-UP!", "#00FF00");
                   } else {
                      statsRef.current.equipment[loot.type as EquipmentSlot] = {
                         id: uuidv4(),
                         name: loot.name,
                         type: loot.type as EquipmentSlot,
                         statBoost: loot.statBoost,
                         description: loot.description
                      };
                      addFloatingText(player.x, player.y - 20, `AUTO: ${loot.name}`, "#00FF00");
                   }
                   didStatsChange = true;
                } else {
                   addFloatingText(player.x, player.y - 20, `DESCARTADO: ${loot.name}`, "#888888");
                }

             } else {
                // Manual Loot Prompt
                nearbyLootId = enemy.id;
             }
          }
          if (getTileAt(enemy.x, enemy.y + enemy.h + 2) === 0) {
             enemy.vy += GRAVITY;
             enemy.y += enemy.vy;
             if (getTileAt(enemy.x, enemy.y + enemy.h) === 1) {
                enemy.y = Math.floor(enemy.y / TILE_SIZE) * TILE_SIZE + (TILE_SIZE - enemy.h);
                enemy.vy = 0;
             }
          }
          return; 
        }
      }

      // Normal Alive Behavior
      // --- KNOCKBACK RECOVERY & MOVEMENT ---
      enemy.vy += GRAVITY;
      
      const targetSpeed = ENEMY_SPEED_BASE + (stage % 10)*0.1;
      
      // If moving faster than target speed (Knockback), apply friction
      if (Math.abs(enemy.vx) > targetSpeed) {
        enemy.vx *= 0.9;
      } else if (Math.abs(enemy.vx) < targetSpeed && Math.abs(enemy.vx) > 0.1) {
        // Snap back to normal patrol speed
        enemy.vx = Math.sign(enemy.vx) * targetSpeed;
      }
      
      const isGrounded = getTileAt(enemy.x + enemy.w/2, enemy.y + enemy.h + 2) === 1;
      const nextX = enemy.x + enemy.vx;
      const wallCheckY = enemy.y + enemy.h - 4; 
      const wallTile = enemy.vx > 0 ? getTileAt(nextX + enemy.w, wallCheckY) : getTileAt(nextX, wallCheckY);

      let pitDetected = false;
      if (isGrounded && Math.abs(enemy.vx) <= targetSpeed * 1.5) { // Only check for pits if not flying from knockback
         const pitCheckX = enemy.vx > 0 ? nextX + enemy.w : nextX;
         if (getTileAt(pitCheckX, enemy.y + enemy.h + 2) === 0) pitDetected = true;
      }

      if (wallTile === 1 || pitDetected) {
        enemy.vx *= -1;
      } else {
        enemy.x += enemy.vx;
      }

      enemy.y += enemy.vy;
      if (enemy.vy > 0) {
         if (getTileAt(enemy.x, enemy.y + enemy.h) === 1 || getTileAt(enemy.x + enemy.w, enemy.y + enemy.h) === 1) {
           enemy.y = Math.floor(enemy.y / TILE_SIZE) * TILE_SIZE + (TILE_SIZE - enemy.h);
           enemy.vy = 0;
         }
      }

      // Player Interaction
      if (checkCollision(player, enemy) && !enemy.isDead) {
        const hitFromTop = player.vy > 0 && (player.y + player.h) < (enemy.y + enemy.h * 0.7);
        
        if (hitFromTop) {
          // HIT ENEMY
          const newHp = (enemy.hp || 1) - 1;
          enemy.hp = newHp;
          
          player.vy = -10; // Bounce high
          
          if (newHp <= 0) {
            // KILL
            enemy.isDead = true;
            enemy.respawnTime = Date.now() + RESPAWN_TIME_MS;
            spawnParticles(enemy.x + enemy.w/2, enemy.y + enemy.h/2, '#8B4513', 12);
            
            // XP Logic
            const xpGain = (enemy.isBoss ? 200 : 15) + (stage * 2);
            stats.xp += xpGain;
            
            // Level Up Check
            if (stats.xp >= stats.maxXp) {
               stats.xp -= stats.maxXp;
               stats.level++;
               stats.maxHp++; 
               stats.hp = stats.maxHp; 
               // Exponential increase: 1.5 multiplier (was 1.3)
               stats.maxXp = Math.floor(stats.maxXp * 1.5);
               
               spawnParticles(player.x, player.y, '#FFD700', 40);
               addFloatingText(player.x, player.y - 20, "NIVEL SUBIU!", "#FFD700");
               addFloatingText(player.x, player.y - 40, "HP MÁXIMO UP!", "#00FF00");
            } else {
               addFloatingText(player.x, player.y - 20, `+${xpGain} XP`, "#FFFFFF");
            }
            didStatsChange = true;
          } else {
             // HIT BUT ALIVE (Boss or strong enemy)
             addFloatingText(enemy.x, enemy.y, "POW!", "#FFFFFF");
             
             // Knockback Logic: Push away from player
             const dir = (enemy.x + enemy.w/2) > (player.x + player.w/2) ? 1 : -1;
             enemy.vx = dir * 8; // Strong push
             enemy.vy = -4; // Small bounce
             
             spawnParticles(enemy.x + enemy.w/2, enemy.y, '#FF0000', 5);
          }
          
        } else {
          // PLAYER HURT
          player.vy = -5;
          player.vx = player.x < enemy.x ? -8 : 8;
          
          // Defense Calc: Helmet + Armor + Pants + Accessory
          let defense = 0;
          if (stats.equipment.HELMET) defense += stats.equipment.HELMET.statBoost;
          if (stats.equipment.ARMOR) defense += stats.equipment.ARMOR.statBoost;
          if (stats.equipment.PANTS) defense += stats.equipment.PANTS.statBoost;
          if (stats.equipment.ACCESSORY) defense += stats.equipment.ACCESSORY.statBoost;

          const damage = Math.max(1, (enemy.isBoss ? 3 : 1) - Math.floor(defense / 3)); 
          
          stats.hp -= damage;
          didStatsChange = true;
          addFloatingText(player.x, player.y - 20, `-${damage} HP`, "#FF0000");

          if (stats.hp <= 0) handlePlayerDeath();
        }
      }
    });

    if (didStatsChange) syncStats();
    setLootTargetId(nearbyLootId);

    // 6. Manual Loot Trigger (Still works if Auto Loot OFF or for Bosses)
    if (nearbyLootId && (keysRef.current['e'] || keysRef.current['E'])) {
       triggerLoot(nearbyLootId);
       keysRef.current['e'] = false; 
    }

    // 7. Particles & Text
    particlesRef.current.forEach(p => { p.x += p.vx; p.y += p.vy; p.life -= 0.05; });
    particlesRef.current = particlesRef.current.filter(p => p.life > 0);
    
    floatingTextsRef.current.forEach(t => { t.y += t.vy; t.life -= 0.02; });
    floatingTextsRef.current = floatingTextsRef.current.filter(t => t.life > 0);
  };

  const triggerLoot = (enemyId: string) => {
    const enemy = enemiesRef.current.find(e => e.id === enemyId);
    if (enemy && !enemy.isLooted) {
      enemy.isLooted = true;
      setGameState(GameState.LOOT_MODAL);
      handleLootGeneration(enemy);
    }
  };

  const handleLootGeneration = async (enemy: Entity) => {
    setIsLoadingLoot(true);
    let loot: GeneratedLootData;
    
    // Only use AI for Bosses to keep standard gameplay fast
    if (enemy.isBoss) {
      try {
        loot = await generateLoot(statsRef.current.level);
      } catch {
        loot = { name: 'Moeda de Ouro', type: 'ACCESSORY', statBoost: 1, description: 'Brilhante!' };
      }
    } else {
      // Instant Loot for mobs
      loot = generateFastLoot(statsRef.current.level);
    }

    setFoundLoot(loot);
    setIsLoadingLoot(false);
  };

  const equipLoot = (shouldEquip: boolean) => {
    if (shouldEquip && foundLoot) {
      const s = statsRef.current;
      
      if (foundLoot.type === 'LIFE') {
         s.lives++;
         addFloatingText(playerRef.current.x, playerRef.current.y, "1-UP!", "#FF0000");
      } else {
         s.equipment = { 
           ...s.equipment, 
           [foundLoot.type]: {
             id: uuidv4(),
             name: foundLoot.name,
             type: foundLoot.type,
             statBoost: foundLoot.statBoost,
             description: foundLoot.description
           } 
         };
      }
      syncStats();
    }
    setFoundLoot(null);
    setGameState(GameState.PLAYING);
  };

  const getLootIcon = (type: string) => {
    switch(type) {
      case 'LIFE': return '❤';
      case 'BOOTS': return '👢';
      case 'HELMET': return '⛑️';
      case 'ARMOR': return '👕';
      case 'PANTS': return '👖';
      case 'GLOVES': return '🧤';
      case 'ACCESSORY': return '💍';
      default: return '🎁';
    }
  };

  // --- Drawing System ---
  const drawHero = (ctx: CanvasRenderingContext2D, p: Entity) => {
    const isRun = Math.abs(p.vx) > 0.5;
    const isJump = Math.abs(p.vy) > 0.5;
    const cycle = (frameRef.current * 0.4) % (Math.PI * 2);
    const legSwing = isRun ? Math.sin(cycle) * 8 : 0;
    
    // Check equipped items for coloring
    const equip = statsRef.current.equipment;
    
    // Helper to get color from item strength (bronze -> iron -> gold -> diamond)
    const getGearColor = (item: any, defaultColor: string) => {
       if (!item) return defaultColor;
       const strength = item.statBoost;
       if (strength > 12) return '#b9f2ff'; // Diamond
       if (strength > 8) return '#ffd700'; // Gold
       if (strength > 5) return '#c0c0c0'; // Iron
       if (strength > 2) return '#cd7f32'; // Bronze
       return '#888888'; // Stone/Leather
    };

    const pantsColor = getGearColor(equip.PANTS, '#0044cc'); 
    const shoeColor = getGearColor(equip.BOOTS, '#cc0000'); 
    const shirtColor = getGearColor(equip.ARMOR, '#cc0000'); 
    const gloveColor = getGearColor(equip.GLOVES, '#f0f0f0'); 
    const skinColor = '#ffccaa';

    ctx.save();
    ctx.translate(p.x + p.w/2, p.y + p.h/2);
    ctx.scale(p.facing || 1, 1);

    // Cape (Dynamic Flow)
    const capeSwing = isRun ? Math.sin(frameRef.current * 0.2) * 5 : 0;
    const capeGradient = ctx.createLinearGradient(-10, -10, -10, 20);
    capeGradient.addColorStop(0, '#ff3333');
    capeGradient.addColorStop(1, '#990000');
    
    ctx.fillStyle = capeGradient;
    ctx.beginPath();
    ctx.moveTo(-6, -10);
    ctx.lineTo(-14 - capeSwing, 20); // Bottom left tip
    ctx.lineTo(-2 - capeSwing, 20); // Bottom right tip
    ctx.lineTo(6, -10);
    ctx.fill();

    // Legs
    const drawLeg = (isBack: boolean) => {
       ctx.save();
       ctx.translate(0, 10);
       let rot = 0;
       if (isJump) {
         rot = isBack ? 0.5 : -0.5;
       } else {
         rot = isBack ? -legSwing * 0.05 : legSwing * 0.05;
       }
       // Adjust position for rotation
       if (!isBack && !isJump) ctx.translate(-legSwing, 0);
       if (isBack && !isJump) ctx.translate(legSwing, 0);
       
       ctx.rotate(rot);

       // Leg
       ctx.fillStyle = pantsColor; 
       drawRoundedRect(ctx, -5, 0, 9, 14, 3);
       
       // Boot
       const bootGrad = ctx.createLinearGradient(-6, 12, 6, 18);
       bootGrad.addColorStop(0, shoeColor);
       bootGrad.addColorStop(1, '#220000');
       ctx.fillStyle = bootGrad; 
       drawRoundedRect(ctx, -6, 10, 12, 8, 3);
       ctx.restore();
    };

    drawLeg(true); // Back leg
    drawLeg(false); // Front leg

    // Torso
    const torsoGrad = ctx.createLinearGradient(-7, -10, 7, 10);
    torsoGrad.addColorStop(0, shirtColor);
    torsoGrad.addColorStop(1, '#000000'); // Shadow
    ctx.fillStyle = torsoGrad; 
    drawRoundedRect(ctx, -7, -12, 14, 24, 4);
    
    // Belt
    ctx.fillStyle = '#333'; 
    drawRoundedRect(ctx, -7, 8, 14, 4, 1); 
    ctx.fillStyle = '#ffd700';
    drawRoundedRect(ctx, -2, 8, 4, 4, 1); // Buckle

    // Arms
    const drawArm = (isBack: boolean) => {
      ctx.save(); ctx.translate(0, -5);
      let rot = 0;
      if (isJump) {
        rot = Math.PI * 0.8; // Hands up!
      } else if (isRun) {
        rot = isBack ? legSwing * 0.1 : -legSwing * 0.1;
      }
      ctx.rotate(rot);
      
      // Sleeve/Arm
      ctx.fillStyle = shirtColor; 
      drawRoundedRect(ctx, -3, 0, 6, 14, 3);
      
      // Glove/Hand
      ctx.fillStyle = gloveColor; 
      drawCircle(ctx, 0, 14, 5, gloveColor);
      ctx.restore();
    };

    drawArm(true);
    drawArm(false);

    // Head
    ctx.translate(0, -16);
    
    // Face
    const faceGrad = ctx.createRadialGradient(0,0, 2, 0,0, 10);
    faceGrad.addColorStop(0, skinColor);
    faceGrad.addColorStop(1, '#dcbbaa');
    ctx.fillStyle = faceGrad; 
    ctx.beginPath(); ctx.arc(0, 0, 10, 0, Math.PI * 2); ctx.fill();
    
    // Face Details
    drawCircle(ctx, 8, 2, 3, skinColor); // Nose
    ctx.fillStyle = 'white'; drawCircle(ctx, 4, -3, 3.5, 'white'); // Eye white
    ctx.fillStyle = '#00aaee'; drawCircle(ctx, 5, -3, 1.5, '#00aaee'); // Iris
    
    // Hair or Helmet
    if (equip.HELMET) {
      const helmColor = getGearColor(equip.HELMET, '#C0C0C0');
      // Helmet Graphic
      const helmGrad = ctx.createLinearGradient(-5, -10, 5, 0);
      helmGrad.addColorStop(0, 'white'); // Shine
      helmGrad.addColorStop(0.5, helmColor);
      helmGrad.addColorStop(1, '#333');
      
      ctx.fillStyle = helmGrad;
      ctx.beginPath(); 
      ctx.arc(0, -2, 11, Math.PI, 0); // Dome
      ctx.lineTo(8, 8); 
      ctx.lineTo(4, 2);
      ctx.lineTo(-4, 2);
      ctx.lineTo(-8, 8);
      ctx.fill();
      // Plume
      ctx.fillStyle = '#d00';
      ctx.beginPath(); ctx.moveTo(0,-13); ctx.quadraticCurveTo(8, -20, 10, -8); ctx.quadraticCurveTo(0, -13, 0, -13); ctx.fill();
    } else {
      // Blonde Spiky Hair
      ctx.fillStyle = '#FBD000'; 
      ctx.beginPath(); 
      ctx.arc(0, -2, 10, Math.PI, 2 * Math.PI); // Top skull
      // Spikes
      ctx.moveTo(-10, -5); ctx.lineTo(-14, -10); ctx.lineTo(-6, -10);
      ctx.lineTo(-8, -18); ctx.lineTo(0, -12);
      ctx.lineTo(8, -18); ctx.lineTo(6, -10);
      ctx.lineTo(14, -10); ctx.lineTo(10, -5);
      ctx.fill();
    }

    ctx.restore();
  };

  const drawEnemy = (ctx: CanvasRenderingContext2D, e: Entity) => {
    const anim = Math.sin(frameRef.current * 0.2);
    ctx.save();
    ctx.translate(e.x + e.w/2, e.y + e.h/2);

    // BOSS SCALE
    if (e.isBoss) {
      const bossPulse = 1 + Math.sin(frameRef.current * 0.1) * 0.05;
      ctx.scale(bossPulse, bossPulse);
    }

    if (e.isDead) {
      ctx.scale(1, 0.2); ctx.translate(0, 50); ctx.globalAlpha = 0.6; 
    }

    if (e.variant === 'CRAB') {
       const crabWalk = anim * 3;
       // Legs
       ctx.strokeStyle = '#c0392b'; ctx.lineWidth = 3; ctx.beginPath();
       ctx.moveTo(-10, 5); ctx.lineTo(-20, 12 + crabWalk); 
       ctx.moveTo(-8, 8); ctx.lineTo(-18, 16 - crabWalk);
       ctx.moveTo(10, 5); ctx.lineTo(20, 12 - crabWalk); 
       ctx.moveTo(8, 8); ctx.lineTo(18, 16 + crabWalk); ctx.stroke();
       
       // Shell (Gradient)
       const shellGrad = ctx.createRadialGradient(-5, -10, 2, 0, 0, 20);
       shellGrad.addColorStop(0, '#e74c3c');
       shellGrad.addColorStop(1, '#7b241c');
       ctx.fillStyle = shellGrad; 
       ctx.beginPath(); ctx.ellipse(0, 0, e.w/2, e.h/3, 0, 0, Math.PI*2); ctx.fill();
       
       // Claws
       ctx.fillStyle = '#922b21'; 
       ctx.beginPath(); ctx.arc(-20, -5 + crabWalk, 6, 0, Math.PI*2); ctx.fill();
       ctx.beginPath(); ctx.arc(20, -5 - crabWalk, 6, 0, Math.PI*2); ctx.fill();
       
       // Eyes
       ctx.fillStyle = 'white'; drawCircle(ctx, -6, -8, 4, 'white'); drawCircle(ctx, 6, -8, 4, 'white');
       ctx.fillStyle = 'black'; drawCircle(ctx, -6, -8, 1.5, 'black'); drawCircle(ctx, 6, -8, 1.5, 'black');

    } else if (e.variant === 'EYE') {
       const hover = Math.sin(frameRef.current * 0.1) * 3;
       ctx.translate(0, hover);
       
       // Wings
       ctx.fillStyle = '#5b2c6f'; 
       ctx.beginPath(); ctx.moveTo(10, 0); ctx.lineTo(30, -15 + hover); ctx.lineTo(18, 10); ctx.fill();
       ctx.beginPath(); ctx.moveTo(-10, 0); ctx.lineTo(-30, -15 + hover); ctx.lineTo(-18, 10); ctx.fill();
       
       // Eye Ball (Gradient)
       const eyeGrad = ctx.createRadialGradient(0,0, 5, 0,0, 15);
       eyeGrad.addColorStop(0, '#f5eef8');
       eyeGrad.addColorStop(1, '#d2b4de');
       ctx.fillStyle = eyeGrad; 
       ctx.beginPath(); ctx.arc(0, 0, e.w/2 - 2, 0, Math.PI * 2); ctx.fill();
       
       // Iris
       const irisPulse = 1 + Math.sin(frameRef.current*0.5) * 0.1;
       ctx.scale(irisPulse, irisPulse);
       ctx.fillStyle = '#8e44ad'; drawCircle(ctx, 0, 0, e.w/4, '#8e44ad');
       ctx.fillStyle = 'black'; drawCircle(ctx, 0, 0, e.w/8, 'black');
       
       // Veins
       ctx.strokeStyle = 'rgba(200, 50, 50, 0.3)';
       ctx.lineWidth = 1;
       ctx.beginPath(); ctx.moveTo(0,0); ctx.lineTo(10, 10); ctx.moveTo(0,0); ctx.lineTo(-10, 8); ctx.stroke();

    } else {
       // BLOB (Default - Slime)
       const squish = Math.abs(Math.sin(frameRef.current * 0.2)) * 5;
       
       // Translucent Gel Body
       const slimeGrad = ctx.createRadialGradient(-5, -5, 5, 0, 0, 20);
       slimeGrad.addColorStop(0, '#2ecc71');
       slimeGrad.addColorStop(1, '#145a32');
       
       ctx.fillStyle = slimeGrad; 
       ctx.beginPath();
       ctx.moveTo(-15 - squish/2, 16);
       ctx.bezierCurveTo(-20 - squish, -15 + squish, 20 + squish, -15 + squish, 15 + squish/2, 16);
       ctx.fill();
       
       // Shine
       ctx.fillStyle = 'rgba(255,255,255,0.4)';
       ctx.beginPath(); ctx.ellipse(-8, -5, 4, 2, -0.5, 0, Math.PI*2); ctx.fill();
       
       // Face
       ctx.fillStyle = 'black'; drawCircle(ctx, -5, 0 + squish, 2, 'black'); drawCircle(ctx, 5, 0 + squish, 2, 'black');
    }

    ctx.restore();
  };

  const drawBackground = (ctx: CanvasRenderingContext2D, width: number, height: number, theme: WorldTheme) => {
    // Sky Gradient
    const grad = ctx.createLinearGradient(0, 0, 0, height);
    grad.addColorStop(0, theme.sky[0]);
    grad.addColorStop(1, theme.sky[1]);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, width, height);

    // Sun or Moon
    const isNight = theme.sky[0] === '#2c3e50';
    const orbColor = isNight ? '#fdfefe' : '#f1c40f';
    const orbGlow = isNight ? 'rgba(255,255,255,0.2)' : 'rgba(241, 196, 15, 0.3)';
    
    // Orb
    ctx.shadowBlur = 40;
    ctx.shadowColor = orbColor;
    ctx.fillStyle = orbColor;
    ctx.beginPath(); ctx.arc(width - 100, 80, 40, 0, Math.PI*2); ctx.fill();
    ctx.shadowBlur = 0; // Reset

    // Parallax Clouds
    const t = frameRef.current * 0.5;
    ctx.fillStyle = isNight ? 'rgba(100,100,120,0.5)' : 'rgba(255,255,255,0.6)';
    const camX = cameraRef.current.x;

    for (let i = 0; i < 5; i++) {
       const cx = ((i * 300) - (camX * 0.5) + t) % (width + 300) - 150;
       const cy = 50 + i * 35;
       // Fluffy cloud shape
       ctx.beginPath(); 
       ctx.arc(cx, cy, 30, 0, Math.PI*2); 
       ctx.arc(cx+25, cy-15, 35, 0, Math.PI*2); 
       ctx.arc(cx+50, cy, 30, 0, Math.PI*2);
       ctx.arc(cx+25, cy+10, 30, 0, Math.PI*2);
       ctx.fill();
    }
    
    // Far Hills (Parallax)
    const hillColor = isNight ? '#1a252f' : 'rgba(39, 174, 96, 0.4)';
    ctx.fillStyle = hillColor;
    for(let i=0; i<3; i++) {
      const hx = ((i * 600) - (camX * 0.2)) % (width + 600) - 300;
      ctx.beginPath();
      ctx.moveTo(hx, height);
      ctx.quadraticCurveTo(hx + 200, height - 300, hx + 400, height);
      ctx.fill();
    }
  };

  const drawLevel = (ctx: CanvasRenderingContext2D, camX: number, width: number, height: number) => {
    const startCol = Math.floor(camX / TILE_SIZE);
    const endCol = startCol + Math.ceil(width / TILE_SIZE) + 1;
    const theme = getTheme(Math.ceil(stage / LEVELS_PER_WORLD));

    for (let y = 0; y < LEVEL_HEIGHT; y++) {
      for (let x = startCol; x < endCol; x++) {
        const rawTile = getRawTileAt(x * TILE_SIZE, y * TILE_SIZE);
        
        if (rawTile > 0) {
           const px = x * TILE_SIZE - camX;
           const py = y * TILE_SIZE;
           
           if (rawTile === 1) { // Ground
              // 1. Base Gradient for Block
              const groundGrad = ctx.createLinearGradient(px, py, px, py + TILE_SIZE);
              groundGrad.addColorStop(0, theme.ground);
              groundGrad.addColorStop(1, theme.groundDark);
              ctx.fillStyle = groundGrad;
              ctx.fillRect(px, py, TILE_SIZE, TILE_SIZE);

              // 2. Texture (Noise)
              ctx.fillStyle = 'rgba(0,0,0,0.1)';
              for(let i=0; i<4; i++) {
                 ctx.fillRect(px + (x*33+i*7)%30, py + (y*22+i*11)%30, 4, 4);
              }

              // 3. Top Grass/Surface
              if (getTileAt(x * TILE_SIZE, (y - 1) * TILE_SIZE) === 0) {
                 ctx.fillStyle = theme.grass;
                 ctx.fillRect(px, py, TILE_SIZE, 8);
                 ctx.fillStyle = theme.grassHighlight;
                 ctx.fillRect(px, py, TILE_SIZE, 4);
                 
                 // 4. Decorations (Procedural Grass Blades)
                 const seed = Math.sin(x * 999); // Pseudo random based on x
                 if (seed > 0) {
                    ctx.fillStyle = theme.grass;
                    // Draw random tufts
                    ctx.beginPath();
                    ctx.moveTo(px + 5, py); ctx.lineTo(px + 8, py - 6); ctx.lineTo(px + 11, py);
                    if (seed > 0.5) {
                       ctx.moveTo(px + 20, py); ctx.lineTo(px + 23, py - 8); ctx.lineTo(px + 26, py);
                    }
                    ctx.fill();
                    
                    // Rare Flower
                    if (seed > 0.9) {
                       ctx.fillStyle = 'white'; drawCircle(ctx, px + 35, py - 4, 3, 'white');
                       ctx.fillStyle = 'yellow'; drawCircle(ctx, px + 35, py - 4, 1.5, 'yellow');
                    }
                 }
              }
           } 
           else if (rawTile === 2) { // Brick Block
              ctx.fillStyle = '#444'; // Mortar
              ctx.fillRect(px, py, TILE_SIZE, TILE_SIZE);
              
              ctx.fillStyle = theme.brick;
              // Draw 4 bricks
              const gap = 2;
              const bw = (TILE_SIZE - gap*3)/2;
              const bh = (TILE_SIZE - gap*3)/2;
              
              // Helper to draw beveled brick
              const drawBrick = (bx: number, by: number) => {
                 const bGrad = ctx.createLinearGradient(bx, by, bx+bw, by+bh);
                 bGrad.addColorStop(0, theme.brick);
                 bGrad.addColorStop(1, theme.brickDark);
                 ctx.fillStyle = bGrad;
                 ctx.fillRect(bx, by, bw, bh);
                 // Highlight
                 ctx.fillStyle = 'rgba(255,255,255,0.2)';
                 ctx.fillRect(bx, by, bw, 2);
                 ctx.fillRect(bx, by, 2, bh);
              };

              drawBrick(px + gap, py + gap);
              drawBrick(px + gap + bw + gap, py + gap);
              drawBrick(px + gap, py + gap + bh + gap);
              drawBrick(px + gap + bw + gap, py + gap + bh + gap);
           }
        }
      }
    }

    // Flagpole
    const flagpoleX = (mapRef.current[0].length - 5) * TILE_SIZE - camX;
    const flagpoleY = (LEVEL_HEIGHT - 3) * TILE_SIZE;
    
    // Pole Gradient
    const poleGrad = ctx.createLinearGradient(flagpoleX, 0, flagpoleX + 10, 0);
    poleGrad.addColorStop(0, '#27ae60');
    poleGrad.addColorStop(0.5, '#a9dfbf');
    poleGrad.addColorStop(1, '#1e8449');
    ctx.fillStyle = poleGrad; 
    ctx.fillRect(flagpoleX, flagpoleY - 200, 10, 200);
    
    // Ball
    const ballGrad = ctx.createRadialGradient(flagpoleX+5, flagpoleY-210, 2, flagpoleX+5, flagpoleY-210, 8);
    ballGrad.addColorStop(0, 'white');
    ballGrad.addColorStop(1, '#f1c40f');
    ctx.fillStyle = ballGrad; 
    ctx.beginPath(); ctx.arc(flagpoleX + 5, flagpoleY - 210, 8, 0, Math.PI*2); ctx.fill();
    
    // Flag (Waving)
    ctx.fillStyle = '#c0392b'; 
    ctx.beginPath(); 
    const wave = Math.sin(frameRef.current * 0.1) * 5;
    ctx.moveTo(flagpoleX+10, flagpoleY-200); 
    ctx.lineTo(flagpoleX+60, flagpoleY-180 + wave); 
    ctx.lineTo(flagpoleX+10, flagpoleY-160); 
    ctx.fill();
  };

  const drawHUD = (ctx: CanvasRenderingContext2D, width: number) => {
     // Loot prompt
     if (lootTargetId) {
        ctx.fillStyle = 'white';
        ctx.font = '12px "Press Start 2P"';
        ctx.textAlign = 'center';
        // Draw higher up to avoid overlap with new HUD layout if on mobile/small screen
        ctx.fillText("Pressione E para procurar um item", width/2, 100);
     }
     
     // Floating Texts
     floatingTextsRef.current.forEach(t => {
        ctx.fillStyle = t.color;
        ctx.font = '10px "Press Start 2P"';
        ctx.fillText(t.text, t.x - cameraRef.current.x, t.y);
     });
  };

  // --- Rendering Loop ---
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Resize handling
    const resize = () => {
       canvas.width = window.innerWidth;
       canvas.height = window.innerHeight;
    };
    window.addEventListener('resize', resize);
    resize();

    const loop = () => {
      update();
      
      const camX = cameraRef.current.x;
      const theme = getTheme(Math.ceil(stage / LEVELS_PER_WORLD));

      // 1. Clear & Background
      drawBackground(ctx, canvas.width, canvas.height, theme);

      // 2. Level
      ctx.save();
      // Y-offset to center level vertically roughly
      const yOffset = (canvas.height - LEVEL_HEIGHT * TILE_SIZE) / 2;
      ctx.translate(0, yOffset);
      
      drawLevel(ctx, camX, canvas.width, canvas.height);

      // 3. Entities
      ctx.save();
      ctx.translate(-camX, 0);
      
      // Hero
      if (gameState !== GameState.GAME_OVER) {
         drawHero(ctx, playerRef.current);
      }
      
      // Enemies
      enemiesRef.current.forEach(e => {
         if (e.x - camX > -100 && e.x - camX < canvas.width + 100) {
            drawEnemy(ctx, e);
            // Loot prompt icon
            if (e.isDead && !e.isLooted) {
               ctx.fillStyle = 'white';
               ctx.font = '10px Arial';
               ctx.fillText("SAQUEAR", e.x, e.y - 10);
            }
         }
      });

      // Particles
      particlesRef.current.forEach(p => {
         ctx.fillStyle = p.color;
         ctx.globalAlpha = p.life;
         ctx.fillRect(p.x, p.y, p.w, p.h);
         ctx.globalAlpha = 1.0;
      });

      ctx.restore(); // Undo Cam Translation
      
      // HUD Overlay (Floating Text)
      drawHUD(ctx, canvas.width);
      
      ctx.restore(); // Undo Y-Offset

      // Screen Overlays
      if (gameState === GameState.GAME_OVER) {
         ctx.fillStyle = 'rgba(0,0,0,0.8)';
         ctx.fillRect(0, 0, canvas.width, canvas.height);
         ctx.fillStyle = 'red';
         ctx.font = '40px "Press Start 2P"';
         ctx.textAlign = 'center';
         ctx.fillText("FIM DE JOGO", canvas.width/2, canvas.height/2);
         ctx.fillStyle = 'white';
         ctx.font = '16px "Press Start 2P"';
         ctx.fillText("Clique para Reiniciar", canvas.width/2, canvas.height/2 + 50);
      }
      
      if (gameState === GameState.LEVEL_COMPLETE) {
         ctx.fillStyle = 'rgba(0,0,0,0.5)';
         ctx.fillRect(0, 0, canvas.width, canvas.height);
         ctx.fillStyle = '#FFD700';
         ctx.font = '30px "Press Start 2P"';
         ctx.textAlign = 'center';
         const isWorldClear = (stage % LEVELS_PER_WORLD) === 0;
         ctx.fillText(isWorldClear ? "MUNDO COMPLETADO!" : "FASE COMPLETADA!", canvas.width/2, canvas.height/2);
      }

      gameLoopRef.current = requestAnimationFrame(loop);
    };

    gameLoopRef.current = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(gameLoopRef.current);
      window.removeEventListener('resize', resize);
    };
  }, [gameState, stage, autoLoot]);

  // --- Input Handlers ---
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => { keysRef.current[e.key] = true; };
    const handleKeyUp = (e: KeyboardEvent) => { keysRef.current[e.key] = false; };
    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('keyup', handleKeyUp);
    
    // Canvas Click for Restart
    const canvas = canvasRef.current;
    const handleClick = () => {
       if (gameState === GameState.GAME_OVER) {
          fullReset();
       }
    };
    canvas?.addEventListener('mousedown', handleClick);
    canvas?.addEventListener('touchstart', handleClick);

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
      canvas?.removeEventListener('mousedown', handleClick);
      canvas?.removeEventListener('touchstart', handleClick);
    };
  }, [gameState]);

  // --- Loot Shortcuts Logic ---
  useEffect(() => {
    const handleModalKeys = (e: KeyboardEvent) => {
      if (gameState === GameState.LOOT_MODAL && foundLoot) {
         if (e.key === 'e' || e.key === 'E') equipLoot(true);
         if ((e.key === 'q' || e.key === 'Q') && foundLoot.type !== 'LIFE') equipLoot(false);
      }
    };
    window.addEventListener('keydown', handleModalKeys);
    return () => window.removeEventListener('keydown', handleModalKeys);
  }, [gameState, foundLoot]);

  // --- Mobile Controls logic ---
  const handleTouchStart = (key: string) => { keysRef.current[key] = true; };
  const handleTouchEnd = (key: string) => { keysRef.current[key] = false; };

  return (
    <div className="relative w-full h-screen bg-black overflow-hidden flex items-center justify-center">
      <canvas ref={canvasRef} className="block w-full h-full object-contain" />
      
      {/* HUD Layer */}
      <HUD 
        stats={uiStats} 
        stage={stage} 
        autoLoot={autoLoot} 
        onToggleAutoLoot={() => setAutoLoot(!autoLoot)} 
      />

      {/* Loot Modal */}
      {gameState === GameState.LOOT_MODAL && (
        <div className="absolute inset-0 z-50 flex items-center justify-center bg-black/80">
          <div className="mario-box p-6 max-w-sm w-full text-center">
            {isLoadingLoot ? (
               <div className="text-white font-retro animate-pulse">GERANDO ITEM...</div>
            ) : foundLoot ? (
               <>
                 <h2 className="text-yellow-400 font-retro mb-4 text-xl">ITEM ENCONTRADO!</h2>
                 <div className="text-4xl mb-2">{getLootIcon(foundLoot.type)}</div>
                 <div className="text-white font-retro text-sm mb-2">{foundLoot.name}</div>
                 <div className="text-gray-400 text-xs mb-4">{foundLoot.description}</div>
                 
                 {foundLoot.type !== 'LIFE' && (
                   <div className="mb-4 text-xs font-retro">
                     <div className="text-blue-300">Novo Status: +{foundLoot.statBoost}</div>
                     {/* Comparison Logic */}
                     {(() => {
                        const current = statsRef.current.equipment[foundLoot.type as EquipmentSlot];
                        if (current) {
                           const diff = foundLoot.statBoost - current.statBoost;
                           return (
                             <div className={diff > 0 ? 'text-green-500' : 'text-red-500'}>
                               {diff > 0 ? `MELHOR (+${diff})` : `PIOR (${diff})`} que o atual
                             </div>
                           );
                        } else {
                           return <div className="text-green-500">Espaço Vazio (EQUIPAR!)</div>;
                        }
                     })()}
                   </div>
                 )}

                 <div className="flex gap-2 justify-center">
                   <button 
                     onClick={() => equipLoot(true)}
                     className="bg-green-600 text-white font-retro px-4 py-2 rounded hover:bg-green-500 text-[10px]"
                   >
                     EQUIPAR [E]
                   </button>
                   {foundLoot.type !== 'LIFE' && (
                     <button 
                       onClick={() => equipLoot(false)}
                       className="bg-red-600 text-white font-retro px-4 py-2 rounded hover:bg-red-500 text-[10px]"
                     >
                       RECUSAR [Q]
                     </button>
                   )}
                 </div>
               </>
            ) : null}
          </div>
        </div>
      )}

      {/* Mobile Controls Overlay */}
      <div className="mobile-controls absolute bottom-4 left-4 flex gap-4 z-40">
        <button 
           className="w-16 h-16 bg-white/20 rounded-full border-2 border-white flex items-center justify-center text-3xl select-none active:bg-white/40"
           onTouchStart={() => handleTouchStart('ArrowLeft')}
           onTouchEnd={() => handleTouchEnd('ArrowLeft')}
        >⬅</button>
        <button 
           className="w-16 h-16 bg-white/20 rounded-full border-2 border-white flex items-center justify-center text-3xl select-none active:bg-white/40"
           onTouchStart={() => handleTouchStart('ArrowRight')}
           onTouchEnd={() => handleTouchEnd('ArrowRight')}
        >➡</button>
      </div>

      <div className="mobile-controls absolute bottom-4 right-4 flex gap-4 z-40">
         <button 
           className="w-16 h-16 bg-yellow-500/50 rounded-full border-2 border-white flex items-center justify-center text-xl font-bold select-none active:bg-yellow-500/80"
           onTouchStart={() => handleTouchStart('e')}
           onTouchEnd={() => handleTouchEnd('e')}
        >🖐</button>
        <button 
           className="w-16 h-16 bg-red-500/50 rounded-full border-2 border-white flex items-center justify-center text-xl font-bold select-none active:bg-red-500/80"
           onTouchStart={() => handleTouchStart('ArrowUp')}
           onTouchEnd={() => handleTouchEnd('ArrowUp')}
        >JUMP</button>
      </div>

    </div>
  );
};

export default App;
