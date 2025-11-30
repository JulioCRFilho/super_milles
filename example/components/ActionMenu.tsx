import React from 'react';

interface ActionMenuProps {
  onAttack: () => void;
  onSpecial: () => void;
  onHeal: () => void;
  disabled: boolean;
}

export const ActionMenu: React.FC<ActionMenuProps> = ({ onAttack, onSpecial, onHeal, disabled }) => {
  const btnClass = `
    flex-1 py-4 px-2 border-4 border-black rounded shadow-[4px_4px_0_0_rgba(0,0,0,0.5)]
    font-retro text-xs md:text-sm uppercase tracking-widest transition-transform active:translate-y-1 active:shadow-none
    disabled:opacity-50 disabled:cursor-not-allowed disabled:grayscale
  `;

  return (
    <div className="w-full max-w-2xl bg-mario-blue p-4 rounded-xl border-4 border-white shadow-lg">
      <div className="flex gap-4">
        <button 
          onClick={onAttack} 
          disabled={disabled}
          className={`${btnClass} bg-mario-red hover:bg-red-600 text-white`}
        >
          Jump Attack
        </button>
        <button 
          onClick={onSpecial} 
          disabled={disabled}
          className={`${btnClass} bg-mario-yellow hover:bg-yellow-500 text-black`}
        >
          Fire Flower
        </button>
        <button 
          onClick={onHeal} 
          disabled={disabled}
          className={`${btnClass} bg-green-500 hover:bg-green-600 text-white`}
        >
          Mushroom
        </button>
      </div>
    </div>
  );
};