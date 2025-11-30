import React, { useEffect, useRef } from 'react';
import { LogEntry } from '../types';

interface CombatLogProps {
  logs: LogEntry[];
}

export const CombatLog: React.FC<CombatLogProps> = ({ logs }) => {
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [logs]);

  return (
    <div className="w-full max-w-2xl mt-4 bg-black/80 border-4 border-white p-4 rounded h-32 md:h-40 overflow-y-auto font-retro text-[10px] md:text-xs relative">
      <div className="absolute top-2 right-2 text-gray-500 pointer-events-none">LOG</div>
      <div ref={scrollRef} className="flex flex-col gap-2">
        {logs.map((log) => (
          <div key={log.id} className={`
            ${log.type === 'damage' ? 'text-red-400' : ''}
            ${log.type === 'heal' ? 'text-green-400' : ''}
            ${log.type === 'critical' ? 'text-yellow-400 font-bold' : ''}
            ${log.type === 'info' ? 'text-gray-300' : ''}
          `}>
            {log.type === 'critical' ? '★ ' : '> '}{log.message}
          </div>
        ))}
        {logs.length === 0 && <div className="text-gray-500 italic">Battle started...</div>}
      </div>
    </div>
  );
};