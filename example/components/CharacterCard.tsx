import React from 'react';
import { Character, CharacterType } from '../types';
import { ProgressBar } from './ProgressBar';

interface CharacterCardProps {
  character: Character;
  type: CharacterType;
  isActive: boolean;
  animateDamage: boolean;
  isHeal?: boolean;
}

export const CharacterCard: React.FC<CharacterCardProps> = ({ character, type, isActive, animateDamage, isHeal }) => {
  const isHero = type === CharacterType.HERO;
  
  const shakeClass = animateDamage ? 'animate-bounce' : '';
  const healClass = isHeal ? 'scale-110 shadow-[0_0_20px_rgba(0,255,0,0.8)]' : '';

  // Calculate total stats including equipment
  const weaponBoost = character.weapon?.statBoost || 0;
  const accessoryBoost = character.accessory?.statBoost || 0;
  const totalAttack = character.attack + weaponBoost;
  const totalDefense = character.defense + accessoryBoost;

  return (
    <div className={`
      relative flex flex-col items-center w-48 md:w-64 transition-all duration-300
      ${shakeClass} ${healClass}
    `}>
      {/* Active Turn Indicator (Cursor) */}
      {isActive && (
        <div className="absolute -top-8 animate-bounce text-red-500 font-retro text-2xl drop-shadow-md">
          ▼
        </div>
      )}

      {/* Floating Damage Number placeholder - simplified logic handled by parent or CSS animations in real app */}
      {animateDamage && (
         <div className="absolute top-0 text-red-500 font-bold font-retro text-2xl animate-ping">
           POW!
         </div>
      )}

      {/* Sprite */}
      <div className="w-32 h-32 md:w-40 md:h-40 mb-2 relative z-10">
         <img 
           src={character.imageUrl} 
           alt={character.name}
           className={`
             w-full h-full object-contain drop-shadow-[4px_4px_0_rgba(0,0,0,0.5)] 
             ${!isHero ? 'scale-x-[-1]' : ''}
             ${isActive ? 'brightness-110' : 'brightness-100'}
           `}
         />
      </div>

      {/* Shadow on ground */}
      <div className="w-24 h-4 bg-black/30 rounded-full blur-sm mb-4"></div>

      {/* Stats Box (Mario Style) */}
      <div className="mario-box w-full p-2 bg-black/80">
        <div className="flex justify-between items-end mb-1">
            <h2 className="text-xs font-retro text-white truncate w-2/3">{character.name}</h2>
            <span className="text-[10px] text-mario-yellow font-retro">LVL {character.level}</span>
        </div>
        
        <ProgressBar 
          current={character.currentHp} 
          max={character.maxHp} 
          label="HP" 
          colorClass={isHero ? 'bg-gradient-to-r from-red-500 to-red-600' : 'bg-gradient-to-r from-orange-500 to-orange-600'} 
        />

        {/* Hero Specifics: XP and Equipment Icons */}
        {isHero && (
          <div className="mt-1">
             <div className="w-full h-1 bg-gray-700 rounded mb-2">
                <div 
                  className="h-full bg-blue-400" 
                  style={{width: `${Math.min(100, (character.xp / character.maxXp) * 100)}%`}}
                ></div>
             </div>
             <div className="flex justify-between text-[8px] text-gray-300 font-retro">
                <span>⚔️ {totalAttack}</span>
                <span>🛡️ {totalDefense}</span>
             </div>
             <div className="flex gap-1 mt-1 text-[8px] text-gray-400">
                {character.weapon && <span className="text-yellow-200">[{character.weapon.name}]</span>}
             </div>
          </div>
        )}
      </div>
    </div>
  );
};