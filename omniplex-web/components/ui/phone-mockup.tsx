'use client'

import { motion } from 'framer-motion'

export default function PhoneMockup() {
  return (
    <div className="relative flex items-center justify-center">
      {/* Outer glow */}
      <div
        className="absolute inset-0 rounded-[50px] opacity-20 blur-3xl"
        style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)' }}
      />

      {/* Phone frame */}
      <motion.div
        animate={{ y: [0, -14, 0] }}
        transition={{ duration: 5.5, repeat: Infinity, ease: 'easeInOut' }}
        className="relative w-[260px] h-[540px] md:w-[300px] md:h-[620px]"
      >
        {/* Frame */}
        <div
          className="absolute inset-0 rounded-[44px] border border-[#2B2E3D]"
          style={{ background: 'linear-gradient(160deg, #1E2130 0%, #14161F 100%)' }}
        />

        {/* Screen bezel */}
        <div className="absolute inset-[3px] rounded-[41px] bg-[#090A0F] overflow-hidden">

          {/* Status bar */}
          <div className="flex justify-between items-center px-6 pt-4 pb-2">
            <span className="text-[10px] text-[#A7ABBE] font-medium">9:41</span>
            <div className="flex gap-1 items-center">
              <div className="w-3 h-2 border border-[#A7ABBE] rounded-sm">
                <div className="w-2 h-full bg-green rounded-sm" />
              </div>
            </div>
          </div>

          {/* Dynamic island */}
          <div className="absolute top-3 left-1/2 -translate-x-1/2 w-20 h-5 bg-black rounded-full z-10" />

          {/* App header */}
          <div className="px-5 pt-2 pb-3">
            <p className="text-[10px] text-[#A7ABBE]">Καλημέρα,</p>
            <p className="text-sm font-semibold text-text">Γιώργης 👋</p>
          </div>

          {/* Today's schedule card */}
          <div className="mx-4 rounded-2xl overflow-hidden mb-3" style={{ background: 'linear-gradient(135deg, #4452D8 0%, #7B3EAD 100%)' }}>
            <div className="p-4">
              <p className="text-[10px] text-white/70 uppercase tracking-wider mb-1">Σήμερα</p>
              <p className="text-sm font-bold text-white">CrossFit Endurance</p>
              <div className="flex items-center gap-2 mt-1">
                <div className="w-1 h-1 rounded-full bg-white/60" />
                <p className="text-[10px] text-white/80">18:00 · 60 λεπτά · Στούντιο Β</p>
              </div>
              <div className="mt-3 flex gap-2">
                <div className="flex-1 bg-white/20 rounded-xl py-2 text-center text-[10px] text-white font-medium">Επιβεβαιωμένο ✓</div>
              </div>
            </div>
          </div>

          {/* Upcoming classes */}
          <div className="px-4 mb-2">
            <p className="text-[10px] text-[#A7ABBE] mb-2 uppercase tracking-wider">Επόμενα μαθήματα</p>
            {[
              { name: 'Yoga Flow', time: '09:00', day: 'Τετ', color: '#8DE2BB' },
              { name: 'HIIT Circuit', time: '17:30', day: 'Πεμ', color: '#9A9DFF' },
              { name: 'Pilates', time: '10:00', day: 'Παρ', color: '#C52473' },
            ].map((cls) => (
              <div key={cls.name} className="flex items-center gap-3 py-2 border-b border-[#1E2130] last:border-0">
                <div className="w-6 h-6 rounded-lg flex items-center justify-center text-[8px] font-bold text-white" style={{ background: cls.color }}>
                  {cls.day}
                </div>
                <div className="flex-1">
                  <p className="text-[11px] font-medium text-text">{cls.name}</p>
                  <p className="text-[9px] text-[#A7ABBE]">{cls.time}</p>
                </div>
                <div className="w-5 h-5 rounded-full border border-[#2B2E3D] flex items-center justify-center">
                  <div className="w-2 h-2 rounded-full bg-[#8DE2BB]" />
                </div>
              </div>
            ))}
          </div>

          {/* Bottom nav */}
          <div className="absolute bottom-0 left-0 right-0 flex justify-around items-center px-4 py-3 border-t border-[#1E2130] bg-[#090A0F]">
            {['🏠', '📅', '💪', '👤'].map((icon, i) => (
              <div key={i} className={`flex flex-col items-center gap-1 ${i === 0 ? 'opacity-100' : 'opacity-40'}`}>
                <span className="text-sm">{icon}</span>
                {i === 0 && <div className="w-1 h-1 rounded-full bg-[#4452D8]" />}
              </div>
            ))}
          </div>
        </div>

        {/* Side buttons */}
        <div className="absolute right-[-3px] top-[100px] w-[3px] h-12 bg-[#2B2E3D] rounded-r-sm" />
        <div className="absolute left-[-3px] top-[80px] w-[3px] h-8 bg-[#2B2E3D] rounded-l-sm" />
        <div className="absolute left-[-3px] top-[116px] w-[3px] h-8 bg-[#2B2E3D] rounded-l-sm" />
      </motion.div>

      {/* Reflection blur */}
      <div
        className="absolute bottom-[-30px] left-1/2 -translate-x-1/2 w-[180px] h-[30px] opacity-20 blur-xl"
        style={{ background: 'linear-gradient(135deg, #4452D8, #C52473)' }}
      />
    </div>
  )
}
