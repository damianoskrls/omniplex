'use client'

import { motion } from 'framer-motion'

type RoleId = 'owner' | 'member' | 'trainer' | 'nutritionist'

function OwnerMockup() {
  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <span className="text-xs font-semibold text-[#F5F5FA]">Dashboard</span>
        <div className="flex items-center gap-1.5">
          <div className="w-1.5 h-1.5 rounded-full bg-[#8DE2BB]" />
          <span className="text-[10px] text-[#A7ABBE]">Σήμερα</span>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-2 mb-4">
        {[
          { label: 'Κρατήσεις', value: '24', color: '#4452D8' },
          { label: 'Έσοδα', value: '€840', color: '#8DE2BB' },
          { label: 'Μέλη', value: '142', color: '#7B3EAD' },
          { label: 'Αύριο', value: '18', color: '#C52473' },
        ].map(({ label, value, color }) => (
          <div key={label} className="rounded-lg p-2.5 border" style={{ background: '#1E2130', borderColor: '#2B2E3D' }}>
            <div className="text-[9px] text-[#6B7280] mb-1">{label}</div>
            <div className="text-base font-black" style={{ color }}>{value}</div>
          </div>
        ))}
      </div>

      <div className="rounded-lg p-3 border mb-3" style={{ background: '#1E2130', borderColor: '#2B2E3D' }}>
        <div className="text-[9px] text-[#6B7280] mb-2">Κρατήσεις 7 ημερών</div>
        <div className="flex items-end gap-1 h-10">
          {[4, 7, 5, 9, 6, 8, 11].map((h, i) => (
            <div
              key={i}
              className="flex-1 rounded-t"
              style={{ height: `${(h / 11) * 100}%`, background: i === 6 ? '#4452D8' : '#2B2E3D' }}
            />
          ))}
        </div>
      </div>

      <div className="rounded-lg px-3 py-2 flex items-center gap-2" style={{ background: '#4452D820', border: '1px solid #4452D840' }}>
        <span className="text-xs">🤖</span>
        <span className="text-[10px] text-[#9A9DFF]">AI: +23% έσοδα αυτή την εβδομάδα</span>
      </div>
    </div>
  )
}

function MemberMockup() {
  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <span className="text-xs font-semibold text-[#F5F5FA]">Πρόγραμμά μου</span>
        <span className="text-[10px] text-[#A7ABBE]">Παρ 16 Οκτ</span>
      </div>

      <div className="rounded-xl px-3 py-2.5 mb-4 flex items-center gap-2.5" style={{ background: '#7B3EAD20', border: '1px solid #7B3EAD40' }}>
        <div className="w-6 h-6 rounded-full flex items-center justify-center text-[11px] flex-shrink-0" style={{ background: '#7B3EAD' }}>🤖</div>
        <div>
          <div className="text-[10px] font-semibold text-[#F5F5FA]">AI Agent</div>
          <div className="text-[9px] text-[#9A9DFF]">Βρήκα θέση για Τρίτη 18:00 →</div>
        </div>
      </div>

      {[
        { time: '09:00', name: 'CrossFit WOD', trainer: 'Νίκος Π.', spots: 3 },
        { time: '11:30', name: 'Yoga Flow', trainer: 'Μαρία Κ.', spots: 8 },
        { time: '18:00', name: 'Circuit Training', trainer: 'Γιώργης Δ.', spots: 1 },
      ].map(({ time, name, trainer, spots }) => (
        <div key={time} className="flex items-center gap-3 py-2 border-b last:border-0" style={{ borderColor: '#2B2E3D' }}>
          <span className="text-[10px] font-bold w-10 flex-shrink-0" style={{ color: '#7B3EAD' }}>{time}</span>
          <div className="flex-1 min-w-0">
            <div className="text-[11px] font-semibold text-[#F5F5FA] truncate">{name}</div>
            <div className="text-[9px] text-[#6B7280]">{trainer}</div>
          </div>
          <div
            className="rounded px-1.5 py-0.5 text-[9px] font-medium flex-shrink-0"
            style={{ background: spots <= 3 ? '#C5247320' : '#8DE2BB20', color: spots <= 3 ? '#C52473' : '#8DE2BB' }}
          >
            {spots} θέσεις
          </div>
        </div>
      ))}

      <div className="mt-3 rounded-xl py-2 text-center text-xs font-semibold text-white" style={{ background: 'linear-gradient(135deg, #4452D8, #7B3EAD)' }}>
        Κράτηση σε 10΄΄
      </div>
    </div>
  )
}

function TrainerMockup() {
  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <span className="text-xs font-semibold text-[#F5F5FA]">Πελατολόγιο</span>
        <div className="rounded-lg px-2 py-1 text-[10px] font-medium" style={{ background: '#A4308D20', color: '#A4308D', border: '1px solid #A4308D40' }}>
          12 ενεργοί
        </div>
      </div>

      {[
        { name: 'Αλέξανδρος Κ.', goal: 'Μυϊκή μάζα', progress: 72 },
        { name: 'Ελένη Μ.', goal: 'Αδυνάτισμα', progress: 45 },
        { name: 'Θανάσης Π.', goal: 'Αντοχή', progress: 88 },
      ].map(({ name, goal, progress }) => (
        <div key={name} className="mb-3 p-2.5 rounded-lg border" style={{ background: '#1E2130', borderColor: '#2B2E3D' }}>
          <div className="flex justify-between items-start mb-1.5">
            <div>
              <div className="text-[11px] font-semibold text-[#F5F5FA]">{name}</div>
              <div className="text-[9px] text-[#6B7280]">{goal}</div>
            </div>
            <span className="text-xs font-bold" style={{ color: '#A4308D' }}>{progress}%</span>
          </div>
          <div className="h-1 rounded-full bg-[#2B2E3D]">
            <div className="h-full rounded-full" style={{ width: `${progress}%`, background: '#A4308D' }} />
          </div>
        </div>
      ))}

      <div className="rounded-xl py-2 text-center text-xs font-semibold text-white" style={{ background: 'linear-gradient(135deg, #A4308D, #C52473)' }}>
        + Νέα Συνεδρία
      </div>
    </div>
  )
}

function NutritionistMockup() {
  // r=15.9 → circumference ≈ 100, so pct maps directly to strokeDasharray offset
  const macros = [
    { label: 'Πρωτεΐνη', value: 148, target: 180, color: '#C52473', pct: 82 },
    { label: 'Λίπος', value: 52, target: 70, color: '#9A9DFF', pct: 74 },
    { label: 'Υδ/κες', value: 220, target: 280, color: '#8DE2BB', pct: 79 },
  ]

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <span className="text-xs font-semibold text-[#F5F5FA]">Πλάνο Διατροφής</span>
        <span className="text-[10px] text-[#A7ABBE]">Σήμερα</span>
      </div>

      <div className="flex justify-around mb-4">
        {macros.map(({ label, value, target, color, pct }) => (
          <div key={label} className="flex flex-col items-center gap-1">
            <div className="relative w-14 h-14">
              <svg viewBox="0 0 36 36" className="w-full h-full -rotate-90">
                <circle cx="18" cy="18" r="15.9" fill="none" stroke="#2B2E3D" strokeWidth="2.5" />
                <circle
                  cx="18" cy="18" r="15.9" fill="none"
                  stroke={color} strokeWidth="2.5"
                  strokeDasharray={`${pct} ${100 - pct}`}
                  strokeLinecap="round"
                />
              </svg>
              <div className="absolute inset-0 flex items-center justify-center">
                <span className="text-[9px] font-bold" style={{ color }}>{pct}%</span>
              </div>
            </div>
            <div className="text-[9px] text-[#6B7280]">{label}</div>
            <div className="text-[9px] font-medium text-[#F5F5FA]">{value}/{target}g</div>
          </div>
        ))}
      </div>

      <div className="rounded-lg p-2.5 border mb-3" style={{ background: '#1E2130', borderColor: '#2B2E3D' }}>
        <div className="flex justify-between items-center mb-1.5">
          <div>
            <div className="text-[11px] font-semibold text-[#F5F5FA]">Σοφία Αντ.</div>
            <div className="text-[9px] text-[#6B7280]">Βάρος: 68kg → στόχος 63kg</div>
          </div>
          <div className="text-xs font-bold" style={{ color: '#C52473' }}>-2.1kg</div>
        </div>
        <div className="h-1 rounded-full bg-[#2B2E3D]">
          <div className="h-full rounded-full" style={{ width: '60%', background: 'linear-gradient(90deg, #7B3EAD, #C52473)' }} />
        </div>
      </div>

      <div className="rounded-xl py-2 text-center text-xs font-semibold text-white" style={{ background: 'linear-gradient(135deg, #7B3EAD, #C52473)' }}>
        Marketplace Προφίλ
      </div>
    </div>
  )
}

const MOCKUP_MAP: Record<RoleId, React.ComponentType> = {
  owner: OwnerMockup,
  member: MemberMockup,
  trainer: TrainerMockup,
  nutritionist: NutritionistMockup,
}

export default function RoleMockup({ roleId, color }: { roleId: RoleId; color: string }) {
  const Content = MOCKUP_MAP[roleId]

  return (
    <motion.div
      animate={{ y: [0, -10, 0] }}
      transition={{ duration: 5, repeat: Infinity, ease: 'easeInOut' }}
      className="relative mx-auto w-full"
      style={{ maxWidth: 320 }}
    >
      {/* Ambient glow */}
      <div
        className="absolute -inset-8 rounded-3xl opacity-25 blur-3xl pointer-events-none"
        style={{ background: color }}
      />

      {/* App frame */}
      <div
        className="relative rounded-2xl border overflow-hidden p-4"
        style={{ background: '#14161F', borderColor: '#2B2E3D', boxShadow: `0 32px 80px ${color}18` }}
      >
        {/* Traffic lights */}
        <div className="flex items-center gap-1.5 mb-4">
          <div className="w-2.5 h-2.5 rounded-full" style={{ background: color }} />
          <div className="w-2.5 h-2.5 rounded-full bg-[#2B2E3D]" />
          <div className="w-2.5 h-2.5 rounded-full bg-[#2B2E3D]" />
          <div className="flex-1" />
          <div className="text-[9px] text-[#6B7280] font-medium">omniplex</div>
        </div>
        <Content />
      </div>
    </motion.div>
  )
}
