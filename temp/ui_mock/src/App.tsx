import React, { useState, useMemo, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Plus, X, ArrowUp, ArrowDown, Trash2 } from 'lucide-react';
import { cn } from './lib/utils';

type BlockType = 'duration' | 'point';

type Block = {
  id: string;
  type: BlockType;
  title: string;
  duration: number; // in minutes. 0 for 'point'
  colorIndex: number;
};

const PIXELS_PER_MINUTE = 4;
const SNAP_MINUTES = 5;

const BLOCK_COLORS = [
  'bg-blue-400',
  'bg-emerald-400',
  'bg-amber-400',
  'bg-rose-400',
  'bg-purple-400',
  'bg-cyan-400',
];

function formatTime(minutes: number) {
  let m = minutes % (24 * 60);
  if (m < 0) m += 24 * 60;
  const h = Math.floor(m / 60);
  const min = m % 60;
  return `${h.toString().padStart(2, '0')}:${min.toString().padStart(2, '0')}`;
}

export default function App() {
  const [targetTime, setTargetTime] = useState(13 * 60); // 13:00
  const [targetTimeTitle, setTargetTimeTitle] = useState('目標時刻');
  const [blocks, setBlocks] = useState<Block[]>([
    { id: '1', type: 'duration', title: '移動', duration: 30, colorIndex: 0 },
  ]);
  const [selectedBlockId, setSelectedBlockId] = useState<string | null>(null);
  const [focusInlineBlockId, setFocusInlineBlockId] = useState<string | null>(null);
  const [preciseDraggingId, setPreciseDraggingId] = useState<string | null>(null);

  useEffect(() => {
    if (focusInlineBlockId) {
      const timer = setTimeout(() => {
        const input = document.getElementById(`inline-input-${focusInlineBlockId}`) as HTMLInputElement;
        if (input) {
          input.focus();
          input.select();
          setFocusInlineBlockId(null);
        }
      }, 50);
      return () => clearTimeout(timer);
    }
  }, [focusInlineBlockId]);

  // Calculate start and end times for each block
  const computedBlocks = useMemo(() => {
    let currentEndTime = targetTime;
    const result = [];
    // blocks are ordered from past (index 0) to future (index length-1)
    for (let i = blocks.length - 1; i >= 0; i--) {
      const block = blocks[i];
      const startTime = currentEndTime - block.duration;
      result.unshift({ ...block, startTime, endTime: currentEndTime });
      currentEndTime = startTime;
    }
    return result;
  }, [blocks, targetTime]);

  const handleTargetTimeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const [h, m] = e.target.value.split(':').map(Number);
    if (!isNaN(h) && !isNaN(m)) {
      setTargetTime(h * 60 + m);
    }
  };

  const handleTimeChange = (id: string, timeStr: string) => {
    const [h, m] = timeStr.split(':').map(Number);
    if (isNaN(h) || isNaN(m)) return;
    const newStartTime = h * 60 + m;

    const index = blocks.findIndex(b => b.id === id);
    if (index < 0) return;

    const block = blocks[index];
    const computedBlock = computedBlocks[index];

    if (block.type === 'duration') {
      let newDuration = computedBlock.endTime - newStartTime;
      while (newDuration < 0) newDuration += 24 * 60;
      if (newDuration < 1) newDuration = 1;
      updateBlock(id, { duration: newDuration });
    } else {
      if (index === blocks.length - 1) {
        setTargetTime(newStartTime);
      } else {
        const nextBlock = blocks[index + 1];
        const nextComputed = computedBlocks[index + 1];
        let newDuration = nextComputed.endTime - newStartTime;
        while (newDuration < 0) newDuration += 24 * 60;
        if (newDuration < 1) newDuration = 1;
        updateBlock(nextBlock.id, { duration: newDuration });
      }
    }
  };

  const addBlock = (index: number, type: BlockType = 'duration') => {
    const prevColor = index > 0 ? blocks[index - 1].colorIndex : -1;
    const nextColor = index < blocks.length ? blocks[index].colorIndex : -1;
    let newColorIndex = Math.floor(Math.random() * BLOCK_COLORS.length);
    while (newColorIndex === prevColor || newColorIndex === nextColor) {
      newColorIndex = Math.floor(Math.random() * BLOCK_COLORS.length);
    }

    const newBlock: Block = {
      id: Math.random().toString(36).substring(2, 9),
      type,
      title: type === 'duration' ? '新しい行動' : '新しいイベント',
      duration: type === 'duration' ? 15 : 0,
      colorIndex: newColorIndex,
    };
    const newBlocks = [...blocks];
    newBlocks.splice(index, 0, newBlock);
    setBlocks(newBlocks);
    setFocusInlineBlockId(newBlock.id);
  };

  const updateBlock = (id: string, updates: Partial<Block>) => {
    setBlocks(blocks.map(b => b.id === id ? { ...b, ...updates } : b));
  };

  const deleteBlock = (id: string) => {
    setBlocks(blocks.filter(b => b.id !== id));
  };

  const moveBlock = (id: string, direction: -1 | 1) => {
    const index = blocks.findIndex(b => b.id === id);
    if (index < 0) return;
    const newIndex = index + direction;
    if (newIndex < 0 || newIndex >= blocks.length) return;
    
    const newBlocks = [...blocks];
    const [removed] = newBlocks.splice(index, 1);
    newBlocks.splice(newIndex, 0, removed);
    setBlocks(newBlocks);
  };

  const handleDrag = (id: string, deltaY: number, startDuration: number, isPrecise: boolean = false) => {
    const snap = isPrecise ? 1 : SNAP_MINUTES;
    // deltaY is negative when dragging up (which means increasing duration in column-reverse)
    const deltaDuration = Math.round(-deltaY / PIXELS_PER_MINUTE / snap) * snap;
    let newDuration = startDuration + deltaDuration;
    if (newDuration < 1) newDuration = 1;
    updateBlock(id, { duration: newDuration });
  };

  const selectedBlock = useMemo(() => blocks.find(b => b.id === selectedBlockId), [blocks, selectedBlockId]);
  const isTargetTimeSelected = selectedBlockId === 'target-time';
  const totalDuration = blocks.reduce((acc, b) => acc + b.duration, 0);

  // Scroll to bottom on initial load
  useEffect(() => {
    const container = document.getElementById('timeline-container');
    if (container) {
      container.scrollTop = container.scrollHeight;
    }
  }, []);

  const preciseDraggingIndex = useMemo(() => {
    if (!preciseDraggingId) return -1;
    return blocks.findIndex(b => b.id === preciseDraggingId);
  }, [blocks, preciseDraggingId]);

  return (
    <div className="h-screen w-full bg-stone-50 flex flex-col font-sans text-stone-900 overflow-hidden select-none">
      {/* Header */}
      <header className="bg-white border-b border-stone-200 p-4 shadow-sm z-20 relative flex-shrink-0">
        <div className="max-w-md mx-auto flex justify-between items-center">
          <h1 className="font-bold text-lg text-stone-800 flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-orange-500" />
            逆算タイムライン
          </h1>
          <div className="text-sm font-medium text-stone-500 bg-stone-100 px-3 py-1 rounded-full">
            総所要時間: {totalDuration}分
          </div>
        </div>
      </header>

      {/* Timeline Area */}
      <div 
        className="flex-1 overflow-y-auto relative" 
        id="timeline-container"
      >
        <div className="flex flex-col-reverse p-4 pt-24 pb-32 min-h-full max-w-md mx-auto">
          
          {/* Anchor (Target Time) */}
          <div className="relative flex w-full group mt-2">
            <div className="w-16 flex-shrink-0 relative border-r-2 border-stone-300">
              <div className="absolute -top-3 right-2 text-sm font-bold text-stone-900 bg-stone-50 py-0.5 pl-1">
                <input 
                  type="time" 
                  value={formatTime(targetTime)} 
                  onChange={handleTargetTimeChange}
                  className="bg-transparent border-none outline-none font-bold text-stone-900 w-14 [&::-webkit-calendar-picker-indicator]:hidden cursor-text"
                />
              </div>
            </div>
            <div 
              className={cn(
                "flex-1 ml-2 p-3 rounded-md border text-stone-700 font-bold flex items-center justify-between shadow-sm transition-colors",
                selectedBlockId === 'target-time' ? "bg-orange-50 border-orange-400 ring-1 ring-orange-400" : "bg-stone-200 border-stone-300"
              )}
              onClick={() => setSelectedBlockId('target-time')}
            >
              <input
                id="inline-input-target-time"
                type="text"
                value={targetTimeTitle}
                onChange={(e) => setTargetTimeTitle(e.target.value)}
                onClick={(e) => e.stopPropagation()}
                className="font-bold text-stone-800 truncate leading-tight bg-transparent border-none outline-none w-full focus:ring-1 focus:ring-stone-300 rounded px-1 -ml-1"
              />
              <div className="w-3 h-3 rounded-full bg-stone-400 flex-shrink-0 ml-2" />
            </div>
          </div>

          {/* Blocks */}
          <AnimatePresence mode="popLayout">
            {computedBlocks.slice().reverse().map((block) => {
              const originalIndex = blocks.findIndex(b => b.id === block.id);
              const isAffectedByPreciseDrag = preciseDraggingIndex !== -1 && originalIndex <= preciseDraggingIndex;
              
              return (
                <motion.div 
                  layout
                  initial={{ opacity: 0, scale: 0.9, y: 10 }}
                  animate={{ opacity: 1, scale: 1, y: 0 }}
                  exit={{ opacity: 0, scale: 0.9, transition: { duration: 0.2 } }}
                  transition={{ type: "spring", bounce: 0.4, duration: 0.6 }}
                  key={block.id} 
                  style={{ height: block.type === 'duration' ? `${block.duration * PIXELS_PER_MINUTE}px` : 'auto' }} 
                  className={cn(
                    "relative flex w-full group",
                    block.type === 'point' ? "my-1 items-center" : ""
                  )}
                >
                {/* Timeline Axis & Time */}
                <div className="w-16 flex-shrink-0 relative border-r-2 border-stone-200">
                  <div className={cn(
                    "absolute right-2 text-sm font-medium text-stone-500 bg-stone-50 py-0.5 pl-1",
                    block.type === 'point' ? "-translate-y-1/2 top-1/2" : "-top-3"
                  )}>
                    <input
                      type="time"
                      value={formatTime(block.startTime)}
                      onChange={(e) => handleTimeChange(block.id, e.target.value)}
                      onClick={(e) => e.stopPropagation()}
                      className="bg-transparent border-none outline-none font-medium text-stone-500 w-[46px] text-sm p-0 m-0 leading-none [&::-webkit-calendar-picker-indicator]:hidden cursor-text"
                    />
                  </div>
                  {block.type === 'point' && (
                    <div className={cn(
                      "absolute -right-[5px] top-1/2 -translate-y-1/2 w-2 h-2 rounded-full",
                      BLOCK_COLORS[block.colorIndex % BLOCK_COLORS.length]
                    )} />
                  )}
                </div>
                
                {/* Block Body */}
                {block.type === 'duration' ? (
                  <motion.div 
                    animate={isAffectedByPreciseDrag ? { rotate: [-0.5, 0.5, -0.5], y: [-0.5, 0.5, -0.5] } : { rotate: 0, y: 0 }}
                    transition={{ repeat: Infinity, duration: 0.3 }}
                    className={cn(
                      "flex-1 ml-2 relative rounded-md border shadow-sm overflow-hidden transition-colors bg-white pl-1",
                      selectedBlockId === block.id ? "border-orange-400 ring-1 ring-orange-400" : "border-stone-200 hover:border-stone-300"
                    )}
                    onClick={() => setSelectedBlockId(block.id)}
                  >
                    {/* Drag Handle */}
                    <DragHandle 
                      id={block.id} 
                      duration={block.duration} 
                      onDrag={handleDrag} 
                      onPreciseChange={(id, isPrecise) => setPreciseDraggingId(isPrecise ? id : null)}
                    />
                    
                    {/* Content */}
                    <div className="p-2 flex flex-col justify-start h-full pt-3 pl-2">
                      <input
                        id={`inline-input-${block.id}`}
                        type="text"
                        value={block.title}
                        onChange={(e) => updateBlock(block.id, { title: e.target.value })}
                        onClick={(e) => e.stopPropagation()}
                        className="font-bold text-stone-800 truncate leading-tight bg-transparent border-none outline-none w-full focus:ring-1 focus:ring-stone-300 rounded px-1 -ml-1"
                      />
                      {/* Accent Line under title */}
                      <div className={cn("h-0.5 w-8 rounded-full mt-1 mb-0.5", BLOCK_COLORS[block.colorIndex % BLOCK_COLORS.length])} />
                      {block.duration >= 5 && (
                        <div className="text-xs text-stone-500">{block.duration} min</div>
                      )}
                    </div>
                  </motion.div>
                ) : (
                  <motion.div 
                    animate={isAffectedByPreciseDrag ? { rotate: [-0.5, 0.5, -0.5], y: [-0.5, 0.5, -0.5] } : { rotate: 0, y: 0 }}
                    transition={{ repeat: Infinity, duration: 0.3 }}
                    className={cn(
                      "flex-1 ml-2 relative flex items-center py-2 px-3 rounded-md border shadow-sm transition-colors bg-white",
                      selectedBlockId === block.id ? "border-orange-400 ring-1 ring-orange-400" : "border-stone-200 hover:border-stone-300"
                    )}
                    onClick={() => setSelectedBlockId(block.id)}
                  >
                    <div className={cn("w-1.5 h-1.5 rounded-full mr-2", BLOCK_COLORS[block.colorIndex % BLOCK_COLORS.length])} />
                    <input
                      id={`inline-input-${block.id}`}
                      type="text"
                      value={block.title}
                      onChange={(e) => updateBlock(block.id, { title: e.target.value })}
                      onClick={(e) => e.stopPropagation()}
                      className="font-bold text-stone-800 truncate leading-tight bg-transparent border-none outline-none w-full focus:ring-1 focus:ring-stone-300 rounded px-1 -ml-1"
                    />
                  </motion.div>
                )}
              </motion.div>
            );
          })}
          </AnimatePresence>

          {/* Add Button (Top) */}
          <div className="relative flex w-full group mb-2">
            <div className="w-16 flex-shrink-0 relative border-r-2 border-stone-200 border-dashed" />
            <motion.button 
              onClick={() => addBlock(0)}
              animate={blocks.length === 1 ? { 
                opacity: [0.5, 1, 0.5],
              } : {
                opacity: 1,
              }}
              transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
              className="flex-1 ml-2 flex items-center justify-center gap-2 p-3 border-2 border-dashed border-stone-300 rounded-lg text-stone-500 hover:bg-stone-100 hover:border-stone-400 transition-colors active:scale-[0.98]"
            >
              <Plus size={20} />
              <span className="font-medium">前の行動を追加</span>
            </motion.button>
          </div>

        </div>
      </div>

      {/* Edit Sheet */}
      <AnimatePresence>
        {(selectedBlock || isTargetTimeSelected) && (
          <>
            <motion.div 
              initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              className="fixed inset-0 bg-black/20 z-40 backdrop-blur-sm"
              onClick={() => setSelectedBlockId(null)}
            />
            <motion.div
              initial={{ y: '100%' }} animate={{ y: 0 }} exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 200 }}
              className="fixed bottom-0 left-0 right-0 bg-white rounded-t-3xl shadow-2xl z-50 p-5 pb-8 max-w-md mx-auto"
            >
              <div className="flex justify-between items-center mb-6">
                <h3 className="font-bold text-lg text-stone-800">
                  {isTargetTimeSelected ? '目標を編集' : '行動を編集'}
                </h3>
                <button onClick={() => setSelectedBlockId(null)} className="p-2 bg-stone-100 rounded-full text-stone-500 hover:bg-stone-200 transition-colors">
                  <X size={20} />
                </button>
              </div>
              
              {/* Title Input */}
              <div className="mb-5">
                <label className="block text-xs font-bold text-stone-500 mb-1.5 uppercase tracking-wider">
                  {isTargetTimeSelected ? '目標名' : '行動名'}
                </label>
                <input 
                  type="text" 
                  value={isTargetTimeSelected ? targetTimeTitle : selectedBlock?.title || ''}
                  onChange={(e) => {
                    if (isTargetTimeSelected) {
                      setTargetTimeTitle(e.target.value);
                    } else if (selectedBlock) {
                      updateBlock(selectedBlock.id, { title: e.target.value });
                    }
                  }}
                  className="w-full p-3.5 bg-stone-100 rounded-xl border-none outline-none focus:ring-2 focus:ring-orange-500 font-bold text-stone-800 text-lg transition-shadow"
                  placeholder={isTargetTimeSelected ? "目標を入力..." : "行動を入力..."}
                />
              </div>
              
              {!isTargetTimeSelected && selectedBlock && (
                <>
                  {/* Duration Input (Only for 'duration' type) */}
                  {selectedBlock.type === 'duration' && (
                    <div className="mb-6">
                      <label className="block text-xs font-bold text-stone-500 mb-1.5 uppercase tracking-wider">所要時間 (分)</label>
                      <div className="flex items-center gap-3">
                        <button 
                          onClick={() => updateBlock(selectedBlock.id, { duration: Math.max(1, selectedBlock.duration - 5) })}
                          className="w-14 h-14 flex items-center justify-center bg-stone-100 rounded-xl text-stone-700 font-bold text-2xl hover:bg-stone-200 active:scale-95 transition-all"
                        >-</button>
                        <input 
                          type="number" 
                          value={selectedBlock.duration}
                          onChange={(e) => updateBlock(selectedBlock.id, { duration: Math.max(1, parseInt(e.target.value) || 1) })}
                          className="flex-1 p-3.5 bg-stone-100 rounded-xl border-none outline-none text-center font-bold text-2xl text-stone-800 focus:ring-2 focus:ring-orange-500 transition-shadow"
                        />
                        <button 
                          onClick={() => updateBlock(selectedBlock.id, { duration: selectedBlock.duration + 5 })}
                          className="w-14 h-14 flex items-center justify-center bg-stone-100 rounded-xl text-stone-700 font-bold text-2xl hover:bg-stone-200 active:scale-95 transition-all"
                        >+</button>
                      </div>
                    </div>
                  )}
                  
                  {/* Action Buttons */}
                  <div className="grid grid-cols-2 gap-3 mb-3">
                    <button onClick={() => moveBlock(selectedBlock.id, -1)} className="p-3.5 flex items-center justify-center gap-2 bg-stone-50 border border-stone-200 rounded-xl text-stone-700 font-medium hover:bg-stone-100 active:scale-95 transition-all">
                      <ArrowUp size={18} /> 上へ (過去)
                    </button>
                    <button onClick={() => moveBlock(selectedBlock.id, 1)} className="p-3.5 flex items-center justify-center gap-2 bg-stone-50 border border-stone-200 rounded-xl text-stone-700 font-medium hover:bg-stone-100 active:scale-95 transition-all">
                      <ArrowDown size={18} /> 下へ (未来)
                    </button>
                  </div>
                  <div className="grid grid-cols-2 gap-3 mb-6">
                    <div className="flex flex-col gap-2">
                      <button onClick={() => addBlock(blocks.findIndex(b => b.id === selectedBlock.id), 'duration')} className="p-3.5 flex items-center justify-center gap-2 bg-stone-50 border border-stone-200 rounded-xl text-stone-700 font-medium hover:bg-stone-100 active:scale-95 transition-all">
                        <Plus size={18} /> 前に行動を追加
                      </button>
                      <button onClick={() => addBlock(blocks.findIndex(b => b.id === selectedBlock.id), 'point')} className="p-2 flex items-center justify-center gap-2 bg-stone-50 border border-stone-200 rounded-xl text-stone-500 text-sm font-medium hover:bg-stone-100 active:scale-95 transition-all">
                        <Plus size={14} /> 前に時点を追加
                      </button>
                    </div>
                    <div className="flex flex-col gap-2">
                      <button onClick={() => addBlock(blocks.findIndex(b => b.id === selectedBlock.id) + 1, 'duration')} className="p-3.5 flex items-center justify-center gap-2 bg-stone-50 border border-stone-200 rounded-xl text-stone-700 font-medium hover:bg-stone-100 active:scale-95 transition-all">
                        <Plus size={18} /> 後に行動を追加
                      </button>
                      <button onClick={() => addBlock(blocks.findIndex(b => b.id === selectedBlock.id) + 1, 'point')} className="p-2 flex items-center justify-center gap-2 bg-stone-50 border border-stone-200 rounded-xl text-stone-500 text-sm font-medium hover:bg-stone-100 active:scale-95 transition-all">
                        <Plus size={14} /> 後に時点を追加
                      </button>
                    </div>
                  </div>
                  
                  <button onClick={() => { deleteBlock(selectedBlock.id); setSelectedBlockId(null); }} className="w-full p-4 flex items-center justify-center gap-2 bg-red-50 text-red-600 rounded-xl font-bold hover:bg-red-100 active:scale-95 transition-all">
                    <Trash2 size={20} /> この行動を削除
                  </button>
                </>
              )}
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </div>
  );
}

// Drag Handle Component
function DragHandle({ 
  id, 
  duration, 
  onDrag,
  onPreciseChange
}: { 
  id: string, 
  duration: number, 
  onDrag: (id: string, deltaY: number, startDuration: number, isPrecise: boolean) => void,
  onPreciseChange?: (id: string, isPrecise: boolean) => void
}) {
  const [isPrecise, setIsPrecise] = useState(false);

  const handlePointerDown = (e: React.PointerEvent) => {
    e.preventDefault();
    e.stopPropagation();
    
    const startY = e.clientY;
    const startDuration = duration;
    let currentPrecise = false;
    let hasMoved = false;

    const longPressTimer = setTimeout(() => {
      if (!hasMoved) {
        currentPrecise = true;
        setIsPrecise(true);
        onPreciseChange?.(id, true);
        if (window.navigator && window.navigator.vibrate) {
          window.navigator.vibrate(50);
        }
      }
    }, 400);
    
    const handlePointerMove = (moveEvent: PointerEvent) => {
      const deltaY = moveEvent.clientY - startY;
      if (Math.abs(deltaY) > 5) {
        hasMoved = true;
      }
      onDrag(id, deltaY, startDuration, currentPrecise);
    };
    
    const handlePointerUp = () => {
      clearTimeout(longPressTimer);
      if (currentPrecise) {
        onPreciseChange?.(id, false);
      }
      setIsPrecise(false);
      window.removeEventListener('pointermove', handlePointerMove);
      window.removeEventListener('pointerup', handlePointerUp);
    };
    
    window.addEventListener('pointermove', handlePointerMove);
    window.addEventListener('pointerup', handlePointerUp);
  };
  
  return (
    <div
      onPointerDown={handlePointerDown}
      className="absolute top-0 left-0 right-0 h-8 -mt-4 z-10 flex justify-center items-center touch-none cursor-ns-resize group/handle"
    >
      <div className={cn(
        "rounded-full transition-all duration-200",
        isPrecise 
          ? "w-16 h-2 bg-orange-500 shadow-sm" 
          : "w-12 h-1.5 bg-stone-300 group-hover/handle:bg-orange-400"
      )} />
    </div>
  );
}
