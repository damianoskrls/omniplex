import { useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import {
  Plus, Pencil, Trash2, X, ChevronDown, ChevronUp, Dumbbell,
  Search, Video, Play, UploadCloud, Check,
} from 'lucide-react';

const isVideoUrl = (url) => url && /\.(mp4|mov|webm|avi)$/i.test(url);

/* Renders video thumbnail (first frame) or image — never broken */
function MediaThumb({ url, size = 40, radius = 8, style = {} }) {
  if (!url) return null;
  const s = { width: size, height: size, objectFit: 'cover', borderRadius: radius, display: 'block', ...style };
  if (isVideoUrl(url)) {
    return (
      <video src={url} muted playsInline preload="metadata"
        style={s}
        onMouseOver={e => e.currentTarget.play()}
        onMouseOut={e => { e.currentTarget.pause(); e.currentTarget.currentTime = 0; }}
      />
    );
  }
  return <img src={url} alt="" style={s} onError={e => { e.target.style.display = 'none'; }} />;
}

const MUSCLE_GROUPS = [
  'Στήθος', 'Πλάτη', 'Ώμοι', 'Δικέφαλοι', 'Τρικέφαλοι',
  'Κοιλιακοί', 'Τετρακέφαλοι', 'Δικέφαλοι μηρού', 'Γλουτοί', 'Γάμπες',
  'Ολόκληρο σώμα', 'Cardio', 'Ισορροπία & Ευλυγισία',
];

/* ─── Animated SVG icons per exercise name / muscle group ─────────────────── */
function ExerciseSVG({ name = '', muscleGroup = '', size = 56 }) {
  const n = name.toLowerCase();
  const mg = (muscleGroup || '').toLowerCase();

  // Lat Pulldown
  if (n.includes('lat pulldown') || n.includes('pulldown')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#eff6ff"/>
      {/* Machine top bar */}
      <rect x="12" y="8" width="32" height="4" rx="2" fill="#3b82f6"/>
      {/* Cable left */}
      <line x1="20" y1="12" x2="20" y2="26" stroke="#64748b" strokeWidth="1.5"/>
      {/* Cable right */}
      <line x1="36" y1="12" x2="36" y2="26" stroke="#64748b" strokeWidth="1.5"/>
      {/* Handle bar */}
      <rect x="16" y="26" width="24" height="3" rx="1.5" fill="#1d4ed8"/>
      {/* Body - torso */}
      <ellipse cx="28" cy="36" rx="6" ry="8" fill="#93c5fd"/>
      {/* Head */}
      <circle cx="28" cy="24" r="4" fill="#fbbf24"/>
      {/* Arms pulling down */}
      <line x1="22" y1="30" x2="16" y2="27" stroke="#1d4ed8" strokeWidth="2.5" strokeLinecap="round">
        <animateTransform attributeName="transform" type="rotate" values="0 22 30;-8 22 30;0 22 30" dur="1.6s" repeatCount="indefinite"/>
      </line>
      <line x1="34" y1="30" x2="40" y2="27" stroke="#1d4ed8" strokeWidth="2.5" strokeLinecap="round">
        <animateTransform attributeName="transform" type="rotate" values="0 34 30;8 34 30;0 34 30" dur="1.6s" repeatCount="indefinite"/>
      </line>
      {/* Seat */}
      <rect x="21" y="43" width="14" height="3" rx="1.5" fill="#cbd5e1"/>
    </svg>
  );

  // Pull-up / Assisted pull-up
  if (n.includes('pull-up') || n.includes('pullup') || n.includes('chin')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#f0fdf4"/>
      <rect x="10" y="8" width="36" height="4" rx="2" fill="#16a34a"/>
      {/* Hands on bar */}
      <circle cx="20" cy="12" r="3" fill="#fbbf24"/>
      <circle cx="36" cy="12" r="3" fill="#fbbf24"/>
      {/* Arms */}
      <line x1="20" y1="15" x2="26" y2="22" stroke="#15803d" strokeWidth="2.5" strokeLinecap="round"/>
      <line x1="36" y1="15" x2="30" y2="22" stroke="#15803d" strokeWidth="2.5" strokeLinecap="round"/>
      {/* Body moving up/down */}
      <g>
        <animateTransform attributeName="transform" type="translate" values="0,0;0,-5;0,0" dur="2s" repeatCount="indefinite" additive="sum"/>
        <ellipse cx="28" cy="30" rx="6" ry="8" fill="#86efac"/>
        <circle cx="28" cy="20" r="4" fill="#fbbf24"/>
        {/* Legs */}
        <line x1="24" y1="38" x2="22" y2="46" stroke="#15803d" strokeWidth="2" strokeLinecap="round"/>
        <line x1="32" y1="38" x2="34" y2="46" stroke="#15803d" strokeWidth="2" strokeLinecap="round"/>
      </g>
    </svg>
  );

  // Seated Row / Barbell Row / Bench Row
  if (n.includes('row')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#fdf4ff"/>
      {/* Machine */}
      <rect x="6" y="30" width="10" height="18" rx="2" fill="#a855f7"/>
      <rect x="6" y="22" width="10" height="10" rx="1" fill="#7c3aed"/>
      {/* Cable */}
      <line x1="16" y1="28" x2="32" y2="28" stroke="#64748b" strokeWidth="1.5" strokeDasharray="3,2"/>
      {/* Handle */}
      <rect x="32" y="26" width="6" height="4" rx="2" fill="#7c3aed"/>
      {/* Person seated */}
      <circle cx="42" cy="22" r="4" fill="#fbbf24"/>
      <ellipse cx="42" cy="32" rx="5" ry="7" fill="#c4b5fd"/>
      {/* Arms pulling */}
      <line x1="37" y1="30" x2="31" y2="28" stroke="#7c3aed" strokeWidth="2.5" strokeLinecap="round">
        <animateTransform attributeName="transform" type="translate" values="0,0;4,0;0,0" dur="1.4s" repeatCount="indefinite"/>
      </line>
      {/* Seat */}
      <rect x="37" y="38" width="14" height="3" rx="1.5" fill="#e9d5ff"/>
      <rect x="48" y="30" width="3" height="11" rx="1" fill="#e9d5ff"/>
    </svg>
  );

  // Chest Press / Bench Press / Incline
  if (n.includes('chest') || n.includes('bench press') || n.includes('incline')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#fff7ed"/>
      {/* Bench */}
      <rect x="8" y="34" width="40" height="5" rx="2.5" fill="#fb923c"/>
      <rect x="10" y="39" width="4" height="8" rx="1.5" fill="#ea580c"/>
      <rect x="42" y="39" width="4" height="8" rx="1.5" fill="#ea580c"/>
      {/* Machine frame */}
      <rect x="6" y="8" width="4" height="30" rx="2" fill="#f97316"/>
      <rect x="46" y="8" width="4" height="30" rx="2" fill="#f97316"/>
      <rect x="10" y="8" width="36" height="4" rx="2" fill="#f97316"/>
      {/* Bar */}
      <rect x="14" y="18" width="28" height="3" rx="1.5" fill="#1e293b">
        <animate attributeName="y" values="18;24;18" dur="1.6s" repeatCount="indefinite"/>
      </rect>
      {/* Weights */}
      <rect x="10" y="16" width="5" height="7" rx="1" fill="#475569">
        <animate attributeName="y" values="16;22;16" dur="1.6s" repeatCount="indefinite"/>
      </rect>
      <rect x="41" y="16" width="5" height="7" rx="1" fill="#475569">
        <animate attributeName="y" values="16;22;16" dur="1.6s" repeatCount="indefinite"/>
      </rect>
      {/* Lying person */}
      <circle cx="28" cy="28" r="4" fill="#fbbf24"/>
      <ellipse cx="28" cy="34" rx="6" ry="3" fill="#fed7aa"/>
    </svg>
  );

  // Leg Press
  if (n.includes('leg press')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#f0fdf4"/>
      {/* Machine seat */}
      <rect x="30" y="28" width="18" height="12" rx="2" fill="#22c55e"/>
      <rect x="42" y="10" width="6" height="22" rx="2" fill="#16a34a"/>
      {/* Platform */}
      <rect x="8" y="14" width="22" height="16" rx="2" fill="#86efac">
        <animateTransform attributeName="transform" type="translate" values="0,0;6,0;0,0" dur="1.4s" repeatCount="indefinite"/>
      </rect>
      {/* Person */}
      <circle cx="36" cy="24" r="4" fill="#fbbf24"/>
      {/* Legs */}
      <line x1="33" y1="28" x2="24" y2="20" stroke="#15803d" strokeWidth="3" strokeLinecap="round">
        <animateTransform attributeName="transform" type="rotate" values="0 33 28;15 33 28;0 33 28" dur="1.4s" repeatCount="indefinite"/>
      </line>
      <line x1="37" y1="28" x2="28" y2="22" stroke="#15803d" strokeWidth="3" strokeLinecap="round">
        <animateTransform attributeName="transform" type="rotate" values="0 37 28;15 37 28;0 37 28" dur="1.4s" repeatCount="indefinite"/>
      </line>
    </svg>
  );

  // Leg Extension
  if (n.includes('leg extension')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#ecfdf5"/>
      {/* Machine */}
      <rect x="6" y="20" width="20" height="28" rx="2" fill="#10b981"/>
      <rect x="16" y="36" width="4" height="12" rx="2" fill="#059669">
        <animateTransform attributeName="transform" type="rotate" values="0 18 36;-30 18 36;0 18 36" dur="1.4s" repeatCount="indefinite"/>
      </rect>
      {/* Pad */}
      <rect x="14" y="46" width="8" height="4" rx="2" fill="#6ee7b7">
        <animateTransform attributeName="transform" type="rotate" values="0 18 36;-30 18 36;0 18 36" dur="1.4s" repeatCount="indefinite"/>
      </rect>
      {/* Person seated */}
      <circle cx="36" cy="22" r="5" fill="#fbbf24"/>
      <ellipse cx="36" cy="32" rx="6" ry="8" fill="#6ee7b7"/>
      <line x1="30" y1="38" x2="22" y2="46" stroke="#059669" strokeWidth="2.5" strokeLinecap="round"/>
      <line x1="42" y1="38" x2="46" y2="46" stroke="#059669" strokeWidth="2.5" strokeLinecap="round"/>
    </svg>
  );

  // Leg Curl
  if (n.includes('leg curl') || n.includes('hamstring')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#fefce8"/>
      {/* Bench */}
      <rect x="8" y="26" width="40" height="6" rx="3" fill="#eab308"/>
      {/* Person lying face down */}
      <ellipse cx="28" cy="24" rx="16" ry="4" fill="#fde68a"/>
      <circle cx="10" cy="22" r="4" fill="#fbbf24"/>
      {/* Legs curling */}
      <line x1="36" y1="30" x2="44" y2="38" stroke="#a16207" strokeWidth="3" strokeLinecap="round">
        <animateTransform attributeName="transform" type="rotate" values="0 36 30;-35 36 30;0 36 30" dur="1.4s" repeatCount="indefinite"/>
      </line>
      <line x1="40" y1="30" x2="48" y2="38" stroke="#a16207" strokeWidth="3" strokeLinecap="round">
        <animateTransform attributeName="transform" type="rotate" values="0 40 30;-35 40 30;0 40 30" dur="1.4s" repeatCount="indefinite"/>
      </line>
      {/* Pad */}
      <rect x="42" y="36" width="8" height="5" rx="2" fill="#fbbf24">
        <animateTransform attributeName="transform" type="rotate" values="0 40 30;-35 40 30;0 40 30" dur="1.4s" repeatCount="indefinite"/>
      </rect>
    </svg>
  );

  // Calf Raise
  if (n.includes('calf')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#f0f9ff"/>
      {/* Machine top bar */}
      <rect x="12" y="8" width="32" height="5" rx="2.5" fill="#0ea5e9"/>
      <rect x="18" y="13" width="4" height="16" rx="2" fill="#38bdf8"/>
      <rect x="34" y="13" width="4" height="16" rx="2" fill="#38bdf8"/>
      {/* Shoulder pads */}
      <rect x="16" y="29" width="24" height="4" rx="2" fill="#0284c7"/>
      {/* Person */}
      <circle cx="28" cy="24" r="4" fill="#fbbf24"/>
      <ellipse cx="28" cy="32" rx="5" ry="6" fill="#7dd3fc"/>
      {/* Legs */}
      <line x1="24" y1="38" x2="22" y2="46" stroke="#0369a1" strokeWidth="2.5" strokeLinecap="round"/>
      <line x1="32" y1="38" x2="34" y2="46" stroke="#0369a1" strokeWidth="2.5" strokeLinecap="round"/>
      {/* Heels rising */}
      <ellipse cx="22" cy="47" rx="4" ry="2" fill="#bae6fd">
        <animate attributeName="cy" values="47;44;47" dur="1.2s" repeatCount="indefinite"/>
      </ellipse>
      <ellipse cx="34" cy="47" rx="4" ry="2" fill="#bae6fd">
        <animate attributeName="cy" values="47;44;47" dur="1.2s" repeatCount="indefinite"/>
      </ellipse>
    </svg>
  );

  // Cable Curl / Bicep Curl
  if (n.includes('curl') || n.includes('bicep')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#fff1f2"/>
      {/* Cable machine */}
      <rect x="6" y="6" width="8" height="44" rx="2" fill="#f43f5e"/>
      <circle cx="10" cy="42" r="4" fill="#e11d48"/>
      {/* Cable */}
      <path d="M14 42 Q24 42 28 34" stroke="#94a3b8" strokeWidth="1.5" fill="none" strokeDasharray="3,2"/>
      {/* Person */}
      <circle cx="38" cy="18" r="5" fill="#fbbf24"/>
      <ellipse cx="38" cy="28" rx="6" ry="8" fill="#fda4af"/>
      {/* Arm curling */}
      <line x1="33" y1="30" x2="28" y2="36" stroke="#e11d48" strokeWidth="3" strokeLinecap="round">
        <animateTransform attributeName="transform" type="rotate" values="0 33 30;-40 33 30;0 33 30" dur="1.4s" repeatCount="indefinite"/>
      </line>
      <circle cx="28" cy="36" r="3" fill="#fbbf24">
        <animateTransform attributeName="transform" type="rotate" values="0 33 30;-40 33 30;0 33 30" dur="1.4s" repeatCount="indefinite"/>
      </circle>
      {/* Legs */}
      <line x1="34" y1="36" x2="32" y2="46" stroke="#be123c" strokeWidth="2" strokeLinecap="round"/>
      <line x1="42" y1="36" x2="44" y2="46" stroke="#be123c" strokeWidth="2" strokeLinecap="round"/>
    </svg>
  );

  // Triceps Pushdown
  if (n.includes('tricep') || n.includes('pushdown')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#f5f3ff"/>
      {/* Machine */}
      <rect x="6" y="6" width="8" height="44" rx="2" fill="#8b5cf6"/>
      <circle cx="10" cy="14" r="4" fill="#7c3aed"/>
      {/* Cable down */}
      <line x1="14" y1="14" x2="30" y2="18" stroke="#94a3b8" strokeWidth="1.5" strokeDasharray="3,2"/>
      {/* Rope handle */}
      <line x1="28" y1="18" x2="26" y2="26" stroke="#6d28d9" strokeWidth="2"/>
      <line x1="32" y1="18" x2="34" y2="26" stroke="#6d28d9" strokeWidth="2"/>
      {/* Person */}
      <circle cx="38" cy="18" r="5" fill="#fbbf24"/>
      <ellipse cx="38" cy="28" rx="6" ry="8" fill="#c4b5fd"/>
      {/* Arms pushing down */}
      <line x1="32" y1="28" x2="28" y2="36" stroke="#7c3aed" strokeWidth="3" strokeLinecap="round">
        <animateTransform attributeName="transform" type="rotate" values="0 32 28;20 32 28;0 32 28" dur="1.4s" repeatCount="indefinite"/>
      </line>
      <line x1="44" y1="28" x2="48" y2="36" stroke="#7c3aed" strokeWidth="3" strokeLinecap="round">
        <animateTransform attributeName="transform" type="rotate" values="0 44 28;-20 44 28;0 44 28" dur="1.4s" repeatCount="indefinite"/>
      </line>
      <line x1="34" y1="36" x2="32" y2="46" stroke="#5b21b6" strokeWidth="2" strokeLinecap="round"/>
      <line x1="42" y1="36" x2="44" y2="46" stroke="#5b21b6" strokeWidth="2" strokeLinecap="round"/>
    </svg>
  );

  // Cable Woodchop
  if (n.includes('woodchop') || n.includes('cable')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#f0fdf4"/>
      <rect x="6" y="6" width="8" height="44" rx="2" fill="#22c55e"/>
      <circle cx="10" cy="12" r="4" fill="#16a34a"/>
      <path d="M14 12 Q26 20 34 36" stroke="#94a3b8" strokeWidth="1.5" fill="none" strokeDasharray="3,2"/>
      {/* Person rotating */}
      <circle cx="36" cy="22" r="5" fill="#fbbf24"/>
      <g>
        <animateTransform attributeName="transform" type="rotate" values="0 36 32;15 36 32;0 36 32" dur="1.6s" repeatCount="indefinite"/>
        <ellipse cx="36" cy="32" rx="6" ry="8" fill="#86efac"/>
        <line x1="30" y1="28" x2="22" y2="36" stroke="#15803d" strokeWidth="3" strokeLinecap="round"/>
        <line x1="42" y1="28" x2="46" y2="38" stroke="#15803d" strokeWidth="3" strokeLinecap="round"/>
      </g>
      <line x1="32" y1="40" x2="30" y2="50" stroke="#166534" strokeWidth="2" strokeLinecap="round"/>
      <line x1="40" y1="40" x2="42" y2="50" stroke="#166534" strokeWidth="2" strokeLinecap="round"/>
    </svg>
  );

  // Smith Squat / Squat
  if (n.includes('squat')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#fff7ed"/>
      {/* Smith machine frame */}
      <rect x="6" y="6" width="4" height="48" rx="2" fill="#f97316"/>
      <rect x="46" y="6" width="4" height="48" rx="2" fill="#f97316"/>
      <rect x="10" y="8" width="36" height="4" rx="2" fill="#f97316"/>
      {/* Bar */}
      <rect x="10" y="22" width="36" height="3" rx="1.5" fill="#1e293b">
        <animate attributeName="y" values="22;30;22" dur="1.8s" repeatCount="indefinite"/>
      </rect>
      <rect x="6" y="20" width="6" height="7" rx="1" fill="#475569">
        <animate attributeName="y" values="20;28;20" dur="1.8s" repeatCount="indefinite"/>
      </rect>
      <rect x="44" y="20" width="6" height="7" rx="1" fill="#475569">
        <animate attributeName="y" values="20;28;20" dur="1.8s" repeatCount="indefinite"/>
      </rect>
      {/* Person squatting */}
      <circle cx="28" cy="18" r="5" fill="#fbbf24">
        <animate attributeName="cy" values="18;22;18" dur="1.8s" repeatCount="indefinite"/>
      </circle>
      <ellipse cx="28" cy="28" rx="6" ry="6" fill="#fed7aa">
        <animate attributeName="cy" values="28;34;28" dur="1.8s" repeatCount="indefinite"/>
        <animate attributeName="ry" values="6;8;6" dur="1.8s" repeatCount="indefinite"/>
      </ellipse>
    </svg>
  );

  // Shoulder Press / Overhead Press
  if (n.includes('shoulder') || n.includes('overhead') || n.includes('press')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#f0f9ff"/>
      {/* Person */}
      <circle cx="28" cy="18" r="5" fill="#fbbf24"/>
      <ellipse cx="28" cy="30" rx="6" ry="8" fill="#7dd3fc"/>
      <line x1="28" y1="38" x2="24" y2="48" stroke="#0369a1" strokeWidth="2.5" strokeLinecap="round"/>
      <line x1="28" y1="38" x2="32" y2="48" stroke="#0369a1" strokeWidth="2.5" strokeLinecap="round"/>
      {/* Dumbbells pressing up */}
      <rect x="12" y="24" width="10" height="4" rx="2" fill="#1e293b">
        <animate attributeName="y" values="24;16;24" dur="1.6s" repeatCount="indefinite"/>
      </rect>
      <rect x="34" y="24" width="10" height="4" rx="2" fill="#1e293b">
        <animate attributeName="y" values="24;16;24" dur="1.6s" repeatCount="indefinite"/>
      </rect>
      {/* Arms */}
      <line x1="22" y1="28" x2="17" y2="26" stroke="#0284c7" strokeWidth="3" strokeLinecap="round">
        <animate attributeName="y2" values="26;18;26" dur="1.6s" repeatCount="indefinite"/>
        <animate attributeName="x2" values="17;17;17" dur="1.6s" repeatCount="indefinite"/>
      </line>
      <line x1="34" y1="28" x2="39" y2="26" stroke="#0284c7" strokeWidth="3" strokeLinecap="round">
        <animate attributeName="y2" values="26;18;26" dur="1.6s" repeatCount="indefinite"/>
      </line>
    </svg>
  );

  // Romanian Deadlift / Deadlift / RDL
  if (n.includes('deadlift') || n.includes('rdl')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#fef9c3"/>
      {/* Bar on floor */}
      <rect x="10" y="40" width="36" height="4" rx="2" fill="#1e293b">
        <animate attributeName="y" values="40;28;40" dur="1.8s" repeatCount="indefinite"/>
      </rect>
      <rect x="6" y="36" width="8" height="12" rx="2" fill="#475569">
        <animate attributeName="y" values="36;24;36" dur="1.8s" repeatCount="indefinite"/>
      </rect>
      <rect x="42" y="36" width="8" height="12" rx="2" fill="#475569">
        <animate attributeName="y" values="36;24;36" dur="1.8s" repeatCount="indefinite"/>
      </rect>
      {/* Person hinging */}
      <circle cx="28" cy="20" r="5" fill="#fbbf24">
        <animate attributeName="cy" values="20;14;20" dur="1.8s" repeatCount="indefinite"/>
      </circle>
      <line x1="28" y1="25" x2="28" y2="38" stroke="#854d0e" strokeWidth="4" strokeLinecap="round">
        <animateTransform attributeName="transform" type="rotate" values="0 28 38;30 28 38;0 28 38" dur="1.8s" repeatCount="indefinite"/>
      </line>
      <line x1="28" y1="38" x2="20" y2="48" stroke="#854d0e" strokeWidth="3" strokeLinecap="round"/>
      <line x1="28" y1="38" x2="36" y2="48" stroke="#854d0e" strokeWidth="3" strokeLinecap="round"/>
    </svg>
  );

  // Hip Thrust
  if (n.includes('hip thrust') || n.includes('hip')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#fdf4ff"/>
      {/* Bench */}
      <rect x="4" y="28" width="16" height="8" rx="2" fill="#d946ef"/>
      {/* Bar */}
      <rect x="8" y="20" width="40" height="4" rx="2" fill="#1e293b"/>
      <rect x="4" y="18" width="8" height="8" rx="1.5" fill="#475569"/>
      <rect x="44" y="18" width="8" height="8" rx="1.5" fill="#475569"/>
      {/* Person */}
      <circle cx="22" cy="16" r="4" fill="#fbbf24"/>
      <ellipse cx="30" cy="24" rx="10" ry="5" fill="#e879f9">
        <animate attributeName="cy" values="24;20;24" dur="1.4s" repeatCount="indefinite"/>
        <animate attributeName="rx" values="10;11;10" dur="1.4s" repeatCount="indefinite"/>
      </ellipse>
      <line x1="40" y1="26" x2="44" y2="36" stroke="#a21caf" strokeWidth="3" strokeLinecap="round"/>
      <line x1="44" y1="26" x2="48" y2="36" stroke="#a21caf" strokeWidth="3" strokeLinecap="round"/>
    </svg>
  );

  // Plank / Core
  if (n.includes('plank') || mg.includes('κοιλιακ')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#f0fdf4"/>
      {/* Person in plank */}
      <circle cx="10" cy="26" r="5" fill="#fbbf24"/>
      <ellipse cx="28" cy="32" rx="18" ry="5" fill="#6ee7b7">
        <animate attributeName="ry" values="5;4;5" dur="2s" repeatCount="indefinite"/>
      </ellipse>
      {/* Arms */}
      <line x1="18" y1="32" x2="14" y2="40" stroke="#059669" strokeWidth="3" strokeLinecap="round"/>
      {/* Legs */}
      <line x1="42" y1="32" x2="46" y2="40" stroke="#059669" strokeWidth="3" strokeLinecap="round"/>
      {/* Pulse ring */}
      <circle cx="28" cy="30" r="10" stroke="#10b981" strokeWidth="1.5" fill="none" opacity="0.4">
        <animate attributeName="r" values="10;14;10" dur="2s" repeatCount="indefinite"/>
        <animate attributeName="opacity" values="0.4;0;0.4" dur="2s" repeatCount="indefinite"/>
      </circle>
    </svg>
  );

  // Bulgarian Split Squat / Lunge
  if (n.includes('bulgarian') || n.includes('split') || n.includes('lunge')) return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#fff7ed"/>
      {/* Bench for back foot */}
      <rect x="34" y="34" width="16" height="6" rx="2" fill="#fb923c"/>
      <rect x="36" y="40" width="3" height="8" rx="1" fill="#ea580c"/>
      <rect x="45" y="40" width="3" height="8" rx="1" fill="#ea580c"/>
      {/* Person lunging */}
      <circle cx="22" cy="16" r="5" fill="#fbbf24"/>
      <ellipse cx="22" cy="26" rx="5" ry="7" fill="#fed7aa"/>
      {/* Front leg */}
      <line x1="18" y1="32" x2="10" y2="44" stroke="#c2410c" strokeWidth="3" strokeLinecap="round"/>
      <ellipse cx="10" cy="46" rx="4" ry="2" fill="#fb923c"/>
      {/* Back leg on bench */}
      <line x1="26" y1="32" x2="38" y2="36" stroke="#c2410c" strokeWidth="3" strokeLinecap="round">
        <animate attributeName="y1" values="32;28;32" dur="1.6s" repeatCount="indefinite"/>
        <animate attributeName="y2" values="36;32;36" dur="1.6s" repeatCount="indefinite"/>
      </line>
      <ellipse cx="22" cy="26" rx="5" ry="7" fill="none">
        <animate attributeName="cy" values="26;22;26" dur="1.6s" repeatCount="indefinite"/>
      </ellipse>
    </svg>
  );

  // Default dumbbell
  return (
    <svg width={size} height={size} viewBox="0 0 56 56" fill="none">
      <rect width="56" height="56" rx="12" fill="#f1f5f9"/>
      {/* Dumbbell */}
      <rect x="6" y="24" width="10" height="8" rx="2" fill="#94a3b8">
        <animate attributeName="y" values="24;20;24" dur="1.6s" repeatCount="indefinite"/>
      </rect>
      <rect x="40" y="24" width="10" height="8" rx="2" fill="#94a3b8">
        <animate attributeName="y" values="24;20;24" dur="1.6s" repeatCount="indefinite"/>
      </rect>
      <rect x="16" y="26" width="24" height="4" rx="2" fill="#64748b">
        <animate attributeName="y" values="26;22;26" dur="1.6s" repeatCount="indefinite"/>
      </rect>
      <rect x="8" y="22" width="6" height="12" rx="1.5" fill="#475569">
        <animate attributeName="y" values="22;18;22" dur="1.6s" repeatCount="indefinite"/>
      </rect>
      <rect x="42" y="22" width="6" height="12" rx="1.5" fill="#475569">
        <animate attributeName="y" values="22;18;22" dur="1.6s" repeatCount="indefinite"/>
      </rect>
    </svg>
  );
}

/* ─── Program Preview (expand) ─────────────────────────────────────────────── */
function ProgramPreview({ programId }) {
  const [data, setData] = useState(null);
  useEffect(() => {
    api.get(`/client-admin/programs/${programId}`).then(r => setData(r.data)).catch(() => {});
  }, [programId]);
  if (!data) return <div style={{ padding: 16, color: '#94a3b8', fontSize: '0.85rem' }}>Φόρτωση...</div>;
  if (!data.exercises?.length) return <div style={{ padding: 12, color: '#94a3b8', fontSize: '0.85rem' }}>Δεν υπάρχουν ασκήσεις</div>;
  return (
    <div style={{ padding: '12px 16px', borderTop: '1px solid #f1f5f9', display: 'flex', flexDirection: 'column', gap: 6 }}>
      {data.exercises.map((ex, i) => (
        <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '6px 0', borderBottom: i < data.exercises.length - 1 ? '1px solid #f8fafc' : 'none' }}>
          <div style={{ width: 40, height: 40, flexShrink: 0 }}>
            {ex.animation_url
              ? <MediaThumb url={ex.animation_url} size={40} radius={8} />
              : <ExerciseSVG name={ex.exercise_name} muscleGroup={ex.muscle_group} size={40} />
            }
          </div>
          <div style={{ flex: 1 }}>
            <span style={{ fontWeight: 600, fontSize: '0.85rem' }}>{ex.exercise_name}</span>
            {ex.muscle_group && <span style={{ marginLeft: 6, fontSize: '0.7rem', color: '#94a3b8' }}>{ex.muscle_group}</span>}
          </div>
          <div style={{ display: 'flex', gap: 8, fontSize: '0.78rem', color: '#64748b' }}>
            {ex.exercise_sets && <span><strong>{ex.exercise_sets}</strong> σετ</span>}
            {ex.exercise_reps && <span>× <strong>{ex.exercise_reps}</strong></span>}
            {ex.rest_secs && <span>🕐 {ex.rest_secs}″</span>}
          </div>
        </div>
      ))}
    </div>
  );
}

/* ─── Exercise Form ─────────────────────────────────────────────────────────── */
function ExerciseForm({ initial, onSave, onClose }) {
  const [form, setForm] = useState({
    name: initial?.name || '',
    description: initial?.description || '',
    muscle_group: initial?.muscle_group || '',
    animation_url: initial?.animation_url || '',
  });
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [savedId, setSavedId] = useState(initial?.id || null);
  const [dragOver, setDragOver] = useState(false);

  const uploadMedia = async (file, exerciseId) => {
    setUploading(true);
    try {
      const fd = new FormData();
      fd.append('media', file);
      const res = await api.post(`/client-admin/exercises/${exerciseId}/media`, fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const url = res.data?.url
        ? (res.data.url.startsWith('http') ? res.data.url : `http://localhost:3001${res.data.url}`)
        : null;
      if (url) setForm(f => ({ ...f, animation_url: url }));
      toast.success('Το αρχείο ανέβηκε');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα ανεβάσματος');
    } finally {
      setUploading(false);
    }
  };

  const handleFilePick = async (file) => {
    if (!file) return;
    if (savedId) { await uploadMedia(file, savedId); return; }
    if (!form.name.trim()) { toast.error('Βάλε πρώτα όνομα άσκησης'); return; }
    setSaving(true);
    try {
      const res = await api.post('/client-admin/exercises', {
        name: form.name, description: form.description,
        muscle_group: form.muscle_group, animation_url: form.animation_url,
      });
      setSavedId(res.data.id);
      await uploadMedia(file, res.data.id);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally { setSaving(false); }
  };

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) { toast.error('Βάλε όνομα'); return; }
    setSaving(true);
    try {
      if (savedId) {
        await api.patch(`/client-admin/exercises/${savedId}`, form);
        toast.success('Η άσκηση ενημερώθηκε');
      } else {
        await api.post('/client-admin/exercises', form);
        toast.success('Η άσκηση προστέθηκε');
      }
      onSave();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally { setSaving(false); }
  };

  const isVideo = form.animation_url && /\.(mp4|mov|webm|avi)$/i.test(form.animation_url);
  const isYoutube = form.animation_url && (form.animation_url.includes('youtube') || form.animation_url.includes('youtu.be'));

  return (
    <form onSubmit={submit} style={{ display: 'flex', gap: 0 }}>
      {/* Left: preview */}
      <div style={{ width: 180, flexShrink: 0, background: '#0f172a', borderRadius: '0 0 0 12px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 20, gap: 12 }}>
        {form.animation_url ? (
          isVideo
            ? <video src={form.animation_url} autoPlay loop muted style={{ width: '100%', borderRadius: 10 }} />
            : <img src={form.animation_url} alt="" style={{ width: '100%', borderRadius: 10, objectFit: 'contain', maxHeight: 160 }} />
        ) : (
          <ExerciseSVG name={form.name} muscleGroup={form.muscle_group} size={100} />
        )}
        {/* Upload zone */}
        <div
          onDragOver={e => { e.preventDefault(); setDragOver(true); }}
          onDragLeave={() => setDragOver(false)}
          onDrop={e => { e.preventDefault(); setDragOver(false); const f = e.dataTransfer.files[0]; if (f) handleFilePick(f); }}
          onClick={() => document.getElementById('ex-media-input').click()}
          style={{
            border: `1.5px dashed ${dragOver ? '#10b981' : '#334155'}`,
            borderRadius: 8, padding: '8px 10px', textAlign: 'center',
            cursor: 'pointer', width: '100%',
            background: dragOver ? 'rgba(16,185,129,0.1)' : 'transparent',
          }}
        >
          <input id="ex-media-input" type="file" accept="image/*,video/*,.gif" style={{ display: 'none' }}
            onChange={e => { const f = e.target.files[0]; if (f) handleFilePick(f); e.target.value = ''; }} />
          {uploading
            ? <div style={{ color: '#10b981', fontSize: '0.75rem' }}>Ανέβασμα...</div>
            : <><UploadCloud size={16} color="#64748b" /><div style={{ color: '#64748b', fontSize: '0.7rem', marginTop: 3 }}>GIF / MP4 / IMG</div></>
          }
        </div>
        {form.animation_url && (
          <button type="button" onClick={() => setForm(f => ({ ...f, animation_url: '' }))}
            style={{ background: 'none', border: 'none', color: '#64748b', fontSize: '0.72rem', cursor: 'pointer' }}>
            ✕ Αφαίρεση
          </button>
        )}
      </div>

      {/* Right: fields */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 12, padding: '20px 24px' }}>
        <div className="form-group" style={{ marginBottom: 0 }}>
          <label className="form-label">Όνομα άσκησης *</label>
          <input className="form-input" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} placeholder="π.χ. Lat Pulldown..." required />
        </div>
        <div className="form-group" style={{ marginBottom: 0 }}>
          <label className="form-label">Μυϊκή ομάδα</label>
          <select className="form-input" value={form.muscle_group} onChange={e => setForm(f => ({ ...f, muscle_group: e.target.value }))}>
            <option value="">— Επίλεξε —</option>
            {MUSCLE_GROUPS.map(g => <option key={g} value={g}>{g}</option>)}
          </select>
        </div>
        <div className="form-group" style={{ marginBottom: 0 }}>
          <label className="form-label">Περιγραφή / οδηγίες</label>
          <textarea className="form-input" rows={3} value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} placeholder="Βήμα-βήμα οδηγίες..." style={{ resize: 'vertical' }} />
        </div>
        <div className="form-group" style={{ marginBottom: 0 }}>
          <label className="form-label">ή URL media</label>
          <input className="form-input" value={form.animation_url} onChange={e => setForm(f => ({ ...f, animation_url: e.target.value }))}
            placeholder="https://... (GIF, MP4, YouTube)" style={{ fontSize: '0.82rem' }} />
        </div>
        <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
          <button type="button" className="btn btn-secondary" onClick={onClose} style={{ flex: 1 }}>Ακύρωση</button>
          <button type="submit" className="btn btn-primary" disabled={saving || uploading} style={{ flex: 2 }}>
            {saving ? 'Αποθήκευση...' : (initial?.id ? 'Αποθήκευση' : 'Προσθήκη άσκησης')}
          </button>
        </div>
      </div>
    </form>
  );
}

/* ─── Program Builder — modern split layout ────────────────────────────────── */
function ProgramBuilder({ program, exercises, onSave, onClose }) {
  const [name, setName] = useState(program?.name || '');
  const [description, setDescription] = useState(program?.description || '');
  const [items, setItems] = useState(program?.exercises?.map(e => ({
    exercise_id: e.exercise_id, sets: e.exercise_sets || '', reps: e.exercise_reps || '',
    duration_secs: e.duration_secs || '', rest_secs: e.rest_secs || '', notes: e.notes || '',
    _name: e.exercise_name, _muscle: e.muscle_group, _anim: e.animation_url,
  })) || []);
  const [search, setSearch] = useState('');
  const [activeIdx, setActiveIdx] = useState(null);
  const [saving, setSaving] = useState(false);

  const filtered = exercises.filter(e =>
    e.name.toLowerCase().includes(search.toLowerCase()) ||
    (e.muscle_group || '').toLowerCase().includes(search.toLowerCase())
  );

  const addExercise = (ex) => {
    const newIdx = items.length;
    setItems(prev => [...prev, {
      exercise_id: ex.id, sets: '', reps: '', duration_secs: '', rest_secs: '', notes: '',
      _name: ex.name, _muscle: ex.muscle_group, _anim: ex.animation_url,
    }]);
    setActiveIdx(newIdx);
    setSearch('');
  };

  const removeItem = (i) => {
    setItems(prev => prev.filter((_, j) => j !== i));
    setActiveIdx(null);
  };

  const updateItem = (i, key, val) => setItems(prev => prev.map((item, j) => j === i ? { ...item, [key]: val } : item));

  const submit = async (e) => {
    e.preventDefault();
    if (!name.trim()) { toast.error('Βάλε τίτλο'); return; }
    setSaving(true);
    try {
      const payload = {
        name, description,
        exercises: items.map(it => ({
          exercise_id: it.exercise_id,
          sets: it.sets ? Number(it.sets) : null,
          reps: it.reps ? Number(it.reps) : null,
          duration_secs: it.duration_secs ? Number(it.duration_secs) : null,
          rest_secs: it.rest_secs ? Number(it.rest_secs) : null,
          notes: it.notes || null,
        })),
      };
      if (program?.id) {
        await api.patch(`/client-admin/programs/${program.id}`, payload);
        toast.success('Πρόγραμμα ενημερώθηκε');
      } else {
        await api.post('/client-admin/programs', payload);
        toast.success('Πρόγραμμα δημιουργήθηκε');
      }
      onSave();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally { setSaving(false); }
  };

  const activeItem = activeIdx !== null ? items[activeIdx] : null;

  return (
    <form onSubmit={submit} style={{ display: 'flex', height: '100%', minHeight: 500 }}>
      {/* Left panel — exercise list */}
      <div style={{ width: 260, flexShrink: 0, borderRight: '1px solid #f1f5f9', display: 'flex', flexDirection: 'column' }}>
        {/* Header fields */}
        <div style={{ padding: '20px 16px 12px', borderBottom: '1px solid #f1f5f9' }}>
          <input className="form-input" value={name} onChange={e => setName(e.target.value)}
            placeholder="Τίτλος προγράμματος *" required style={{ fontWeight: 700, marginBottom: 8 }} />
          <input className="form-input" value={description} onChange={e => setDescription(e.target.value)}
            placeholder="Περιγραφή (προαιρετικά)" style={{ fontSize: '0.82rem' }} />
        </div>

        {/* Search */}
        <div style={{ padding: '10px 12px', borderBottom: '1px solid #f1f5f9', position: 'relative' }}>
          <Search size={14} style={{ position: 'absolute', left: 22, top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
          <input className="form-input" style={{ paddingLeft: 32, fontSize: '0.82rem' }}
            placeholder="Προσθήκη άσκησης..." value={search} onChange={e => setSearch(e.target.value)} />
          {search && (
            <div style={{ position: 'absolute', left: 12, right: 12, top: '100%', zIndex: 20, background: '#fff', border: '1px solid #e2e8f0', borderRadius: 8, boxShadow: '0 4px 16px rgba(0,0,0,0.1)', maxHeight: 220, overflowY: 'auto' }}>
              {filtered.length === 0 && <div style={{ padding: 12, color: '#94a3b8', fontSize: '0.82rem' }}>Δεν βρέθηκε</div>}
              {filtered.map(ex => (
                <div key={ex.id} onMouseDown={() => addExercise(ex)}
                  style={{ padding: '8px 12px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8 }}
                  onMouseOver={e => e.currentTarget.style.background = '#f8fafc'}
                  onMouseOut={e => e.currentTarget.style.background = ''}>
                  <ExerciseSVG name={ex.name} muscleGroup={ex.muscle_group} size={28} />
                  <div>
                    <div style={{ fontWeight: 600, fontSize: '0.82rem' }}>{ex.name}</div>
                    {ex.muscle_group && <div style={{ fontSize: '0.7rem', color: '#94a3b8' }}>{ex.muscle_group}</div>}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Exercise list */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '8px 0' }}>
          {items.length === 0 && (
            <div style={{ textAlign: 'center', padding: '32px 16px', color: '#94a3b8' }}>
              <Dumbbell size={28} style={{ opacity: 0.3, marginBottom: 8 }} />
              <div style={{ fontSize: '0.8rem' }}>Αναζήτησε για να προσθέσεις ασκήσεις</div>
            </div>
          )}
          {items.map((item, i) => (
            <div key={i} onClick={() => setActiveIdx(i)}
              style={{
                display: 'flex', alignItems: 'center', gap: 8, padding: '8px 12px', cursor: 'pointer',
                background: activeIdx === i ? '#eff6ff' : 'transparent',
                borderLeft: activeIdx === i ? '3px solid #3b82f6' : '3px solid transparent',
              }}
              onMouseOver={e => { if (activeIdx !== i) e.currentTarget.style.background = '#f8fafc'; }}
              onMouseOut={e => { if (activeIdx !== i) e.currentTarget.style.background = 'transparent'; }}
            >
              <div style={{ width: 32, height: 32, flexShrink: 0 }}>
                {item._anim
                  ? <MediaThumb url={item._anim} size={32} radius={6} />
                  : <ExerciseSVG name={item._name} muscleGroup={item._muscle} size={32} />
                }
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 600, fontSize: '0.82rem', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {i + 1}. {item._name}
                </div>
                <div style={{ fontSize: '0.7rem', color: '#94a3b8' }}>
                  {[item.sets && `${item.sets} σετ`, item.reps && `${item.reps} επαν.`].filter(Boolean).join(' · ') || 'Χωρίς παραμέτρους'}
                </div>
              </div>
              <button type="button" onClick={e => { e.stopPropagation(); removeItem(i); }}
                style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4, color: '#cbd5e1', flexShrink: 0 }}
                onMouseOver={e => e.currentTarget.style.color = '#ef4444'}
                onMouseOut={e => e.currentTarget.style.color = '#cbd5e1'}>
                <X size={14} />
              </button>
            </div>
          ))}
        </div>

        {/* Save */}
        <div style={{ padding: '12px 16px', borderTop: '1px solid #f1f5f9', display: 'flex', gap: 8 }}>
          <button type="button" className="btn btn-secondary" onClick={onClose} style={{ flex: 1, fontSize: '0.82rem' }}>Ακύρωση</button>
          <button type="submit" className="btn btn-primary" disabled={saving} style={{ flex: 2, fontSize: '0.82rem' }}>
            <Check size={13} /> {saving ? 'Αποθήκευση...' : (program?.id ? 'Αποθήκευση' : 'Δημιουργία')}
          </button>
        </div>
      </div>

      {/* Right panel — exercise detail */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        {activeItem ? (
          <>
            {/* Exercise header */}
            <div style={{ padding: '20px 24px 16px', borderBottom: '1px solid #f1f5f9', display: 'flex', alignItems: 'center', gap: 14 }}>
              <div style={{ width: 64, height: 64, flexShrink: 0 }}>
                {activeItem._anim
                  ? <MediaThumb url={activeItem._anim} size={64} radius={10} />
                  : <ExerciseSVG name={activeItem._name} muscleGroup={activeItem._muscle} size={64} />
                }
              </div>
              <div>
                <div style={{ fontWeight: 800, fontSize: '1rem' }}>{activeItem._name}</div>
                {activeItem._muscle && (
                  <span style={{ fontSize: '0.72rem', background: '#eff6ff', color: '#3b82f6', borderRadius: 20, padding: '2px 10px', display: 'inline-block', marginTop: 4 }}>
                    {activeItem._muscle}
                  </span>
                )}
              </div>
            </div>

            {/* Parameters */}
            <div style={{ padding: '20px 24px', flex: 1, overflowY: 'auto' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginBottom: 14 }}>
                <div>
                  <label style={{ fontSize: '0.72rem', fontWeight: 700, color: '#64748b', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Σετ</label>
                  <input className="form-input" type="number" min="1" value={activeItem.sets}
                    onChange={e => updateItem(activeIdx, 'sets', e.target.value)} placeholder="π.χ. 3"
                    style={{ fontSize: '1.1rem', fontWeight: 700, textAlign: 'center' }} />
                </div>
                <div>
                  <label style={{ fontSize: '0.72rem', fontWeight: 700, color: '#64748b', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Επαναλήψεις</label>
                  <input className="form-input" type="number" min="1" value={activeItem.reps}
                    onChange={e => updateItem(activeIdx, 'reps', e.target.value)} placeholder="π.χ. 12"
                    style={{ fontSize: '1.1rem', fontWeight: 700, textAlign: 'center' }} />
                </div>
                <div>
                  <label style={{ fontSize: '0.72rem', fontWeight: 700, color: '#64748b', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Διάρκεια (δευτ.)</label>
                  <input className="form-input" type="number" min="1" value={activeItem.duration_secs}
                    onChange={e => updateItem(activeIdx, 'duration_secs', e.target.value)} placeholder="—"
                    style={{ fontSize: '1.1rem', fontWeight: 700, textAlign: 'center' }} />
                </div>
                <div>
                  <label style={{ fontSize: '0.72rem', fontWeight: 700, color: '#64748b', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Ανάπαυση (δευτ.)</label>
                  <input className="form-input" type="number" min="1" value={activeItem.rest_secs}
                    onChange={e => updateItem(activeIdx, 'rest_secs', e.target.value)} placeholder="π.χ. 60"
                    style={{ fontSize: '1.1rem', fontWeight: 700, textAlign: 'center' }} />
                </div>
              </div>

              <div>
                <label style={{ fontSize: '0.72rem', fontWeight: 700, color: '#64748b', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Σημειώσεις προπονητή</label>
                <textarea className="form-input" rows={3} value={activeItem.notes}
                  onChange={e => updateItem(activeIdx, 'notes', e.target.value)}
                  placeholder="π.χ. Ελεγχόμενο εκκεντρικό, κράτα πλάτη ίσια..."
                  style={{ resize: 'vertical' }} />
              </div>
            </div>
          </>
        ) : (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', gap: 12 }}>
            <Dumbbell size={48} style={{ opacity: 0.15 }} />
            <div style={{ fontWeight: 600, color: '#cbd5e1' }}>Επίλεξε άσκηση από αριστερά</div>
            <div style={{ fontSize: '0.82rem' }}>για να ρυθμίσεις σετ, επαναλήψεις και σημειώσεις</div>
          </div>
        )}
      </div>
    </form>
  );
}

/* ─── Main Page ─────────────────────────────────────────────────────────────── */
export default function Programs() {
  const [programs, setPrograms] = useState([]);
  const [exercises, setExercises] = useState([]);
  const [tab, setTab] = useState('programs');
  const [modal, setModal] = useState(null);
  const [expandedProgram, setExpandedProgram] = useState(null);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    setLoading(true);
    try {
      const [pr, ex] = await Promise.all([
        api.get('/client-admin/programs'),
        api.get('/client-admin/exercises'),
      ]);
      setPrograms(pr.data);
      setExercises(ex.data);
    } catch { toast.error('Σφάλμα φόρτωσης'); }
    finally { setLoading(false); }
  };

  useEffect(() => { load(); }, []);

  const deleteProgram = async (id) => {
    if (!confirm('Διαγραφή προγράμματος;')) return;
    await api.delete(`/client-admin/programs/${id}`);
    toast.success('Διαγράφηκε'); load();
  };

  const deleteExercise = async (id) => {
    if (!confirm('Διαγραφή άσκησης;')) return;
    await api.delete(`/client-admin/exercises/${id}`);
    toast.success('Διαγράφηκε'); load();
  };

  const openProgramEdit = async (prog) => {
    try {
      const r = await api.get(`/client-admin/programs/${prog.id}`);
      setModal({ type: 'program', data: r.data });
    } catch { setModal({ type: 'program', data: prog }); }
  };

  return (
    <Layout>
      <div style={{ maxWidth: 960, margin: '0 auto', padding: '24px 16px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
          <div>
            <h1 style={{ margin: 0, fontSize: '1.5rem', fontWeight: 800 }}>Προγράμματα Άσκησης</h1>
            <div style={{ color: '#64748b', fontSize: '0.85rem', marginTop: 2 }}>Δημιούργησε προγράμματα για τους πελάτες σου</div>
          </div>
          <button className="btn btn-primary" onClick={() => setModal({ type: tab === 'exercises' ? 'exercise' : 'program', data: null })}>
            <Plus size={16} /> {tab === 'exercises' ? 'Νέα άσκηση' : 'Νέο πρόγραμμα'}
          </button>
        </div>

        {/* Tabs */}
        <div style={{ display: 'flex', gap: 0, marginBottom: 20, background: '#f1f5f9', borderRadius: 10, padding: 4 }}>
          {[
            { id: 'programs', label: `Προγράμματα (${programs.length})` },
            { id: 'exercises', label: `Βιβλιοθήκη Ασκήσεων (${exercises.length})` },
          ].map(t => (
            <button key={t.id} type="button" onClick={() => setTab(t.id)} style={{
              flex: 1, padding: '8px 16px', borderRadius: 8, border: 'none', cursor: 'pointer',
              fontWeight: tab === t.id ? 700 : 400,
              background: tab === t.id ? '#fff' : 'transparent',
              color: tab === t.id ? '#1e293b' : '#64748b',
              boxShadow: tab === t.id ? '0 1px 3px rgba(0,0,0,0.08)' : 'none',
              fontSize: '0.88rem',
            }}>{t.label}</button>
          ))}
        </div>

        {loading ? (
          <div style={{ textAlign: 'center', padding: 40, color: '#94a3b8' }}>Φόρτωση...</div>
        ) : tab === 'programs' ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {programs.length === 0 && (
              <div style={{ textAlign: 'center', padding: 48, border: '2px dashed #e2e8f0', borderRadius: 14 }}>
                <Dumbbell size={40} style={{ color: '#cbd5e1', marginBottom: 12 }} />
                <div style={{ fontWeight: 700, color: '#475569' }}>Δεν υπάρχουν προγράμματα ακόμα</div>
                <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={() => setModal({ type: 'program', data: null })}>
                  <Plus size={14} /> Νέο πρόγραμμα
                </button>
              </div>
            )}
            {programs.map(prog => (
              <div key={prog.id} style={{ border: '1px solid #e2e8f0', borderRadius: 14, overflow: 'hidden', background: '#fff', boxShadow: '0 1px 4px rgba(0,0,0,0.04)' }}>
                <div style={{ display: 'flex', alignItems: 'center', padding: '14px 16px', cursor: 'pointer', gap: 12 }}
                  onClick={() => setExpandedProgram(expandedProgram === prog.id ? null : prog.id)}>
                  <div style={{ width: 42, height: 42, borderRadius: 10, background: 'linear-gradient(135deg,#3b82f6,#6366f1)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <Dumbbell size={20} color="#fff" />
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontWeight: 700 }}>{prog.name}</div>
                    {prog.description && <div style={{ fontSize: '0.8rem', color: '#64748b', marginTop: 2 }}>{prog.description}</div>}
                  </div>
                  <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                    <button className="btn btn-secondary btn-sm" onClick={e => { e.stopPropagation(); openProgramEdit(prog); }}>
                      <Pencil size={13} />
                    </button>
                    <button className="btn btn-danger btn-sm" onClick={e => { e.stopPropagation(); deleteProgram(prog.id); }}>
                      <Trash2 size={13} />
                    </button>
                    {expandedProgram === prog.id ? <ChevronUp size={16} color="#94a3b8" /> : <ChevronDown size={16} color="#94a3b8" />}
                  </div>
                </div>
                {expandedProgram === prog.id && <ProgramPreview programId={prog.id} />}
              </div>
            ))}
          </div>
        ) : (
          /* Exercise library grid */
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 12 }}>
            {exercises.length === 0 && (
              <div style={{ gridColumn: '1/-1', textAlign: 'center', padding: 40, border: '2px dashed #e2e8f0', borderRadius: 14 }}>
                <div style={{ fontWeight: 700, color: '#475569' }}>Δεν υπάρχουν ασκήσεις ακόμα</div>
                <button className="btn btn-primary" style={{ marginTop: 12 }} onClick={() => setModal({ type: 'exercise', data: null })}>
                  <Plus size={14} /> Νέα άσκηση
                </button>
              </div>
            )}
            {exercises.map(ex => (
              <div key={ex.id} style={{ border: '1px solid #e2e8f0', borderRadius: 14, overflow: 'hidden', background: '#fff', boxShadow: '0 1px 4px rgba(0,0,0,0.04)', display: 'flex', flexDirection: 'column' }}>
                {/* Media / SVG preview */}
                <div style={{ height: 110, display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#f8fafc', position: 'relative' }}>
                  {ex.animation_url ? (
                    /\.(mp4|mov|webm)$/i.test(ex.animation_url)
                      ? <video src={ex.animation_url} autoPlay loop muted style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      : <img src={ex.animation_url} alt={ex.name} style={{ width: '100%', height: '100%', objectFit: 'contain' }} onError={e => { e.target.style.display = 'none'; }} />
                  ) : (
                    <ExerciseSVG name={ex.name} muscleGroup={ex.muscle_group} size={70} />
                  )}
                </div>
                <div style={{ padding: '10px 12px', flex: 1 }}>
                  <div style={{ fontWeight: 700, fontSize: '0.88rem' }}>{ex.name}</div>
                  {ex.muscle_group && (
                    <span style={{ fontSize: '0.7rem', background: '#eff6ff', color: '#3b82f6', borderRadius: 20, padding: '2px 8px', display: 'inline-block', marginTop: 4 }}>
                      {ex.muscle_group}
                    </span>
                  )}
                  {ex.description && <div style={{ fontSize: '0.76rem', color: '#64748b', marginTop: 6, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{ex.description}</div>}
                </div>
                <div style={{ display: 'flex', gap: 6, padding: '0 12px 12px' }}>
                  <button className="btn btn-secondary btn-sm" style={{ flex: 1 }} onClick={() => setModal({ type: 'exercise', data: ex })}>
                    <Pencil size={12} /> Επεξεργασία
                  </button>
                  <button className="btn btn-danger btn-sm" onClick={() => deleteExercise(ex.id)}>
                    <Trash2 size={12} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Modal */}
      {modal && (
        <div className="modal-overlay" onClick={() => setModal(null)}>
          <div className="modal" style={{
            maxWidth: modal.type === 'program' ? 780 : 620,
            width: '95vw',
            padding: 0,
            overflow: 'hidden',
            borderRadius: 16,
          }} onClick={e => e.stopPropagation()}>
            {/* Modal header */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 20px', borderBottom: '1px solid #f1f5f9' }}>
              <div style={{ fontWeight: 800, fontSize: '1rem' }}>
                {modal.type === 'exercise'
                  ? (modal.data?.id ? 'Επεξεργασία άσκησης' : 'Νέα άσκηση')
                  : (modal.data?.id ? 'Επεξεργασία προγράμματος' : 'Νέο πρόγραμμα')}
              </div>
              <button type="button" style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4, color: '#94a3b8' }} onClick={() => setModal(null)}>
                <X size={20} />
              </button>
            </div>
            {modal.type === 'exercise' ? (
              <ExerciseForm initial={modal.data} onSave={() => { setModal(null); load(); }} onClose={() => setModal(null)} />
            ) : (
              <ProgramBuilder program={modal.data} exercises={exercises} onSave={() => { setModal(null); load(); }} onClose={() => setModal(null)} />
            )}
          </div>
        </div>
      )}
    </Layout>
  );
}
