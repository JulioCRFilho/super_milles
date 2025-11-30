import React from 'react';

interface ProgressBarProps {
  current: number;
  max: number;
  label: string;
  colorClass: string;
}

export const ProgressBar: React.FC<ProgressBarProps> = ({ current, max, label, colorClass }) => {
  const percentage = Math.max(0, Math.min(100, (current / max) * 100));

  return (
    <div className="w-full mb-2">
      <div className="flex justify-between text-xs font-retro mb-1 text-white uppercase tracking-wider">
        <span>{label}</span>
        <span>{current}/{max}</span>
      </div>
      <div className="h-4 w-full bg-gray-800 border-2 border-white rounded-sm p-[2px]">
        <div 
          className={`h-full ${colorClass} transition-all duration-500 ease-out`} 
          style={{ width: `${percentage}%` }}
        />
      </div>
    </div>
  );
};