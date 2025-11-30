
import React, { useState } from 'react';
import { PlayerStats, EquipmentSlot, Equipment } from '../types';

interface HUDProps {
  stats: PlayerStats;
  stage: number;
  autoLoot: boolean;
  onToggleAutoLoot: () => void;
}

export const HUD: React.FC<HUDProps> = ({ stats, stage, autoLoot, onToggleAutoLoot }) => {
  const [selectedItem, setSelectedItem] = useState<Equipment | null | undefined>(null);

  const xpPercent = (stats.xp / stats.maxXp) * 100;
  
  // 13 Levels per world
  const LEVELS_PER_WORLD = 13;
  const worldNum = Math.ceil(stage / LEVELS_PER_WORLD);
  const levelNum = (stage - 1) % LEVELS_PER_WORLD + 1;
  const isBossLevel = levelNum === 13;

  // Calculate Totals
  const getStat = (slot: EquipmentSlot) => stats.equipment[slot]?.statBoost || 0;
  const totalAttack = stats.attack + getStat('BOOTS') + getStat('GLOVES');
  const totalDefense = getStat('HELMET') + getStat('ARMOR') + getStat('PANTS') + getStat('ACCESSORY');

  const equipSlots: {id: EquipmentSlot, label: string, icon: string}[] = [
    { id: 'HELMET', label: 'CABEÇA', icon: '‍♂' },
    { id: 'ARMOR', label: 'CORPO', icon: '👕' },
    { id: 'PANTS', label: 'PERNAS', icon: '👖' },
    { id: 'BOOTS', label: 'PÉS', icon: '👢' },
    { id: 'GLOVES', label: 'MÃOS', icon: '🧤' },
    { id: 'ACCESSORY', label: 'JOIA', icon: '💍' },
  ];

  return (
    <div className="absolute top-0 left-0 w-full p-2 md:p-4 pointer-events-none z-10 flex flex-wrap justify-between items-start font-retro text-white drop-shadow-[2px_2px_0_rgba(0,0,0,1)]">
      
      {/* Left Column: Stats, Lives & Equipment */}
      <div className="flex flex-col gap-2 w-1/3 pointer-events-auto">
        {/* Name & Lives */}
        <div>
          <div className="flex items-center gap-2">
            <span className="text-mario-red text-lg md:text-xl">MILLES</span>
          </div>
          <div className="flex items-center gap-1 mb-1">
            {Array.from({ length: Math.min(5, stats.lives) }).map((_, i) => (
               <span key={i} className="text-red-500 text-sm md:text-lg">❤</span>
            ))}
            {stats.lives > 5 && <span className="text-white text-xs">+ {stats.lives - 5}</span>}
          </div>
        </div>

        {/* HP Bar */}
        <div className="flex items-center gap-2 text-[10px] md:text-sm">
          <span>HP</span>
          <div className="w-16 md:w-24 h-3 bg-black border border-white">
            <div 
              className="h-full bg-mario-red transition-all duration-300"
              style={{ width: `${(stats.hp / stats.maxHp) * 100}%` }}
            />
          </div>
        </div>

        {/* Total Stats */}
        <div className="flex gap-3 text-[10px] md:text-xs text-gray-200 mt-1 mb-2">
           <span className="text-yellow-300">ATK: {totalAttack}</span>
           <span className="text-blue-300">DEF: {totalDefense}</span>
        </div>

        {/* Auto Loot Toggle */}
        <div 
          onClick={onToggleAutoLoot}
          className={`
             flex items-center gap-2 cursor-pointer border border-white/50 bg-black/60 px-2 py-1 rounded w-fit mb-2 hover:bg-white/20 transition-all
             ${autoLoot ? 'text-green-400' : 'text-gray-400'}
          `}
        >
          <div className={`w-3 h-3 rounded-full ${autoLoot ? 'bg-green-500 shadow-[0_0_5px_lime]' : 'bg-gray-500'}`}></div>
          <span className="text-[10px] md:text-xs">AUTO-LOOT {autoLoot ? 'ON' : 'OFF'}</span>
        </div>

        {/* Equipment Grid (Moved Here) */}
        <div className="grid grid-cols-3 gap-1 bg-black/40 p-1 rounded border border-white/20 w-fit">
          {equipSlots.map(slot => {
             const item = stats.equipment[slot.id];
             return (
               <div 
                 key={slot.id} 
                 onClick={() => setSelectedItem(item || undefined)}
                 className="w-8 h-8 md:w-10 md:h-10 bg-black/60 border border-white/30 flex flex-col items-center justify-center cursor-pointer hover:bg-white/20 relative"
               >
                  <span className="text-xs">{slot.icon}</span>
                  {item ? (
                    <div className="absolute bottom-0 right-0 w-2 h-2 bg-green-500 rounded-full"></div>
                  ) : (
                    <div className="absolute inset-0 bg-black/50"></div>
                  )}
               </div>
             );
          })}
        </div>

        {/* Selected Item Detail Pop-up */}
        {selectedItem && (
          <div className="mt-2 bg-blue-900 border border-white p-2 text-[10px] w-48 rounded shadow-lg">
             <div className="text-yellow-300 font-bold mb-1">{selectedItem.name}</div>
             <div className="text-white mb-1">Status: +{selectedItem.statBoost}</div>
             <div className="text-gray-300 italic">{selectedItem.description}</div>
             <button 
               className="mt-1 text-red-400 text-[8px] underline" 
               onClick={() => setSelectedItem(null)}
             >
               FECHAR
             </button>
          </div>
        )}
      </div>

      {/* Right: Level Info */}
      <div className="flex flex-col items-end gap-1 w-1/3">
        <span className={`${isBossLevel ? 'text-red-500 animate-pulse' : 'text-mario-blue'} text-lg md:text-xl text-right`}>
            {isBossLevel ? `CHEFE` : `FASE`} {levelNum}-{worldNum}
        </span>
        <div className="text-[10px] md:text-xs">NIVEL {stats.level}</div>
        <div className="w-24 md:w-32 h-2 bg-black border border-white">
           <div 
             className="h-full bg-blue-400 transition-all duration-300"
             style={{ width: `${xpPercent}%` }}
           />
        </div>
      </div>
    </div>
  );
};
