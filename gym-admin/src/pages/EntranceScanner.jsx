// Entrance scanner — gym device scans member QR/barcode
// Two input modes:
//   1. HID hardware scanner (keyboard wedge) — auto-detected via keydown listener
//   2. Camera QR scan (via BarcodeDetector or manual input)

import { useEffect, useState, useRef, useCallback } from 'react';
import { ArrowLeft, Camera, Keyboard, CheckCircle, XCircle, Maximize2, Minimize2 } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import api from '../api/client';

// ── Helpers ──────────────────────────────────────────────────

function formatTime(iso) {
  return new Date(iso).toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' });
}

function remainingLabel(data) {
  if (data.isUnlimited) return 'Απεριόριστη συνδρομή';
  if (data.remaining === null || data.remaining === undefined) return '';
  if (data.remaining <= 0) return 'Τελευταία συνεδρία αφαιρέθηκε — 0 απομένουν';
  return `Απομένουν ${data.remaining} συνεδρίες`;
}

// ── Main component ────────────────────────────────────────────

export default function EntranceScanner() {
  const navigate   = useNavigate();
  const { business } = useAuth();
  const bizId      = business?.id;

  const [mode, setMode]           = useState('hid'); // 'hid' | 'camera'
  const [result, setResult]       = useState(null);  // { success, member, error, code }
  const [scanning, setScanning]   = useState(false);
  const [recentList, setRecentList] = useState([]);
  const [isFullscreen, setIsFullscreen] = useState(false);

  // HID mode: accumulate keyboard chars between scan events
  const hidBufferRef   = useRef('');
  const hidTimerRef    = useRef(null);
  const resultTimerRef = useRef(null);
  const videoRef       = useRef(null);
  const streamRef      = useRef(null);

  // ── Load recent ────────────────────────────────────────────
  const loadRecent = useCallback(async () => {
    if (!bizId) return;
    try {
      const res = await api.get(`/checkin/${bizId}/recent`);
      setRecentList(res.data);
    } catch (_) {}
  }, [bizId]);

  useEffect(() => {
    loadRecent();
    const t = setInterval(loadRecent, 6000);
    return () => clearInterval(t);
  }, [loadRecent]);

  // ── Fullscreen listener ────────────────────────────────────
  useEffect(() => {
    const onFsChange = () => setIsFullscreen(!!document.fullscreenElement);
    document.addEventListener('fullscreenchange', onFsChange);
    return () => document.removeEventListener('fullscreenchange', onFsChange);
  }, []);

  const toggleFullscreen = async () => {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await document.documentElement.requestFullscreen();
    } catch (_) {}
  };

  // ── Scan token → API ────────────────────────────────────────
  const handleToken = useCallback(async (token) => {
    if (!bizId || !token) return;
    setScanning(true);
    try {
      const res = await api.post(`/checkin/${bizId}/scan`, { token });
      setResult({ success: true, ...res.data });
      loadRecent();
    } catch (err) {
      const d = err.response?.data || {};
      setResult({ success: false, error: d.error || 'Σφάλμα', code: d.code, member: d.member });
    } finally {
      setScanning(false);
      if (resultTimerRef.current) clearTimeout(resultTimerRef.current);
      resultTimerRef.current = setTimeout(() => setResult(null), 5000);
    }
  }, [bizId, loadRecent]);

  // ── HID keyboard listener ───────────────────────────────────
  useEffect(() => {
    if (mode !== 'hid') return;

    const onKey = (e) => {
      // Ignore modifier-only keys and special keys except Enter
      if (e.key === 'Enter') {
        const tok = hidBufferRef.current.trim();
        hidBufferRef.current = '';
        if (hidTimerRef.current) { clearTimeout(hidTimerRef.current); hidTimerRef.current = null; }
        if (tok.length > 4) handleToken(tok);
        return;
      }
      if (e.key.length !== 1) return;
      hidBufferRef.current += e.key;
      // Auto-flush after 100ms silence (some scanners don't send Enter)
      if (hidTimerRef.current) clearTimeout(hidTimerRef.current);
      hidTimerRef.current = setTimeout(() => {
        const tok = hidBufferRef.current.trim();
        hidBufferRef.current = '';
        hidTimerRef.current = null;
        if (tok.length > 4) handleToken(tok);
      }, 100);
    };

    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('keydown', onKey);
      if (hidTimerRef.current) clearTimeout(hidTimerRef.current);
    };
  }, [mode, handleToken]);

  // ── Camera: BarcodeDetector ─────────────────────────────────
  useEffect(() => {
    if (mode !== 'camera') {
      // Stop any active stream
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(t => t.stop());
        streamRef.current = null;
      }
      return;
    }

    let active = true;
    let detector = null;
    let scanLoop = null;

    const start = async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: 'environment' },
        });
        if (!active) { stream.getTracks().forEach(t => t.stop()); return; }
        streamRef.current = stream;
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          await videoRef.current.play();
        }

        if ('BarcodeDetector' in window) {
          detector = new window.BarcodeDetector({ formats: ['qr_code', 'code_128', 'ean_13', 'ean_8'] });
          let lastToken = '';
          let lastTime  = 0;
          scanLoop = setInterval(async () => {
            if (!videoRef.current || videoRef.current.readyState < 2) return;
            try {
              const codes = await detector.detect(videoRef.current);
              if (codes.length > 0) {
                const tok = codes[0].rawValue;
                const now = Date.now();
                if (tok !== lastToken || now - lastTime > 3000) {
                  lastToken = tok;
                  lastTime  = now;
                  handleToken(tok);
                }
              }
            } catch (_) {}
          }, 300);
        }
        // If no BarcodeDetector, user can type manually
      } catch (err) {
        console.error('camera error', err);
      }
    };

    start();
    return () => {
      active = false;
      if (scanLoop) clearInterval(scanLoop);
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(t => t.stop());
        streamRef.current = null;
      }
    };
  }, [mode, handleToken]);

  useEffect(() => () => {
    if (resultTimerRef.current) clearTimeout(resultTimerRef.current);
    if (hidTimerRef.current) clearTimeout(hidTimerRef.current);
  }, []);

  // ── Render ─────────────────────────────────────────────────
  return (
    <div style={s.page}>
      {/* Top controls */}
      <div style={s.controls}>
        <button style={s.ctrlBtn} onClick={() => navigate('/')}>
          <ArrowLeft size={15} /> Panel
        </button>
        <button style={s.ctrlBtn} onClick={toggleFullscreen}>
          {isFullscreen ? <Minimize2 size={15} /> : <Maximize2 size={15} />}
          {isFullscreen ? 'Έξοδος' : 'Πλήρης οθόνη'}
        </button>
      </div>

      {/* Title */}
      <div style={s.title}>Scanner Εισόδου</div>
      <div style={s.subtitle}>{business?.name || ''}</div>

      {/* Mode toggle */}
      <div style={s.modeRow}>
        <button
          style={{ ...s.modeBtn, ...(mode === 'hid' ? s.modeBtnActive : {}) }}
          onClick={() => setMode('hid')}
        >
          <Keyboard size={16} /> Hardware scanner
        </button>
        <button
          style={{ ...s.modeBtn, ...(mode === 'camera' ? s.modeBtnActive : {}) }}
          onClick={() => setMode('camera')}
        >
          <Camera size={16} /> Κάμερα
        </button>
      </div>

      {/* Result flash */}
      {result && (
        <div style={{ ...s.flash, background: result.success ? '#16a34a' : '#dc2626' }}>
          {result.success
            ? <CheckCircle size={36} strokeWidth={2.5} />
            : <XCircle size={36} strokeWidth={2.5} />}
          <div>
            <div style={s.flashName}>{result.member?.fullName || result.error}</div>
            <div style={s.flashSub}>
              {result.success
                ? remainingLabel(result)
                : (result.code === 'no_membership' ? 'Δεν υπάρχει ενεργή συνδρομή' : result.error)}
            </div>
          </div>
        </div>
      )}

      {/* Camera view */}
      {mode === 'camera' && (
        <div style={s.cameraWrap}>
          <video ref={videoRef} style={s.video} playsInline muted />
          <div style={s.scanLine} />
          <div style={s.cameraHint}>
            {'BarcodeDetector' in window
              ? 'Στόχευσε το QR του μέλους'
              : 'Το πρόγραμμα περιήγησης δεν υποστηρίζει αυτόματη ανάγνωση — πλήκτρολόγησε τον κωδικό παρακάτω'}
          </div>
          {'BarcodeDetector' in window ? null : (
            <ManualInput onSubmit={handleToken} />
          )}
        </div>
      )}

      {/* HID hint */}
      {mode === 'hid' && (
        <div style={s.hidBox}>
          <div style={s.hidIcon}>
            {scanning ? '⏳' : '📷'}
          </div>
          <div style={s.hidText}>
            {scanning ? 'Επεξεργασία...' : 'Έτοιμο — σκανάρετε τον κωδικό μέλους'}
          </div>
          <div style={s.hidHint}>
            Ο scanner hardware στέλνει αυτόματα τον κωδικό
          </div>
        </div>
      )}

      {/* Recent list */}
      {recentList.length > 0 && (
        <div style={s.list}>
          <div style={s.listTitle}>Σήμερα</div>
          {recentList.slice(0, 10).map(r => (
            <div key={r.id} style={s.row}>
              <div style={s.avatar}>{r.full_name?.charAt(0).toUpperCase()}</div>
              <div style={{ flex: 1 }}>
                <div style={s.rowName}>{r.full_name}</div>
                <div style={s.rowSub}>
                  {r.total_sessions >= 9999
                    ? 'Απεριόριστη'
                    : `${Math.max(0, r.total_sessions - r.used_sessions)} απομένουν`}
                </div>
              </div>
              <div style={s.rowTime}>{formatTime(r.checked_in_at)}</div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function ManualInput({ onSubmit }) {
  const [val, setVal] = useState('');
  return (
    <form
      onSubmit={e => { e.preventDefault(); if (val.trim()) { onSubmit(val.trim()); setVal(''); } }}
      style={{ marginTop: 12, display: 'flex', gap: 8 }}
    >
      <input
        value={val}
        onChange={e => setVal(e.target.value)}
        placeholder="Πληκτρολόγησε κωδικό"
        style={s.manualInput}
        autoFocus
      />
      <button type="submit" style={s.manualBtn}>OK</button>
    </form>
  );
}

// ── Styles ───────────────────────────────────────────────────

const s = {
  page: {
    minHeight: '100vh',
    background: '#0f172a',
    color: '#f8fafc',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '80px 24px 40px',
    fontFamily: 'system-ui, sans-serif',
    position: 'relative',
    gap: 16,
  },
  controls: {
    position: 'fixed',
    top: 16, right: 16,
    display: 'flex', gap: 8,
    zIndex: 200,
  },
  ctrlBtn: {
    display: 'inline-flex', alignItems: 'center', gap: 6,
    padding: '8px 14px',
    borderRadius: 10,
    border: '1px solid #334155',
    background: 'rgba(30,41,59,0.92)',
    color: '#e2e8f0',
    fontSize: 13, fontWeight: 500,
    cursor: 'pointer',
  },
  title: { fontSize: 26, fontWeight: 800, letterSpacing: -0.5 },
  subtitle: { fontSize: 14, color: '#64748b', marginTop: -8 },
  modeRow: { display: 'flex', gap: 10, marginTop: 8 },
  modeBtn: {
    display: 'inline-flex', alignItems: 'center', gap: 7,
    padding: '10px 20px',
    borderRadius: 12,
    border: '1px solid #334155',
    background: '#1e293b',
    color: '#94a3b8',
    fontSize: 14, fontWeight: 500,
    cursor: 'pointer',
    transition: 'all 0.15s',
  },
  modeBtnActive: {
    background: 'rgba(118,192,67,0.15)',
    borderColor: '#76C043',
    color: '#76C043',
  },
  flash: {
    position: 'fixed',
    top: 24, left: '50%', transform: 'translateX(-50%)',
    borderRadius: 18,
    padding: '18px 32px',
    display: 'flex', alignItems: 'center', gap: 18,
    boxShadow: '0 8px 40px rgba(0,0,0,0.5)',
    zIndex: 300,
    maxWidth: 'calc(100% - 48px)',
    animation: 'slideDown 0.25s ease',
  },
  flashName: { fontWeight: 700, fontSize: 22 },
  flashSub: { fontSize: 14, opacity: 0.9, marginTop: 2 },
  hidBox: {
    display: 'flex', flexDirection: 'column', alignItems: 'center',
    gap: 10, padding: '40px 32px',
    background: '#1e293b',
    borderRadius: 20,
    border: '1px solid #334155',
    width: '100%', maxWidth: 400,
    textAlign: 'center',
  },
  hidIcon: { fontSize: 52 },
  hidText: { fontSize: 18, fontWeight: 600 },
  hidHint: { fontSize: 13, color: '#64748b' },
  cameraWrap: {
    position: 'relative',
    width: '100%', maxWidth: 380,
    display: 'flex', flexDirection: 'column', alignItems: 'center',
  },
  video: {
    width: '100%', maxWidth: 380, height: 320,
    borderRadius: 20,
    objectFit: 'cover',
    background: '#1e293b',
    border: '2px solid #334155',
  },
  scanLine: {
    position: 'absolute', top: '50%',
    left: 16, right: 16, height: 2,
    background: '#76C043',
    opacity: 0.7,
    borderRadius: 2,
  },
  cameraHint: { fontSize: 13, color: '#64748b', marginTop: 10, textAlign: 'center' },
  manualInput: {
    flex: 1, padding: '10px 14px',
    borderRadius: 10, border: '1px solid #334155',
    background: '#1e293b', color: '#f8fafc',
    fontSize: 14, outline: 'none',
  },
  manualBtn: {
    padding: '10px 18px', borderRadius: 10,
    border: 'none', background: '#76C043',
    color: '#0f172a', fontWeight: 700, cursor: 'pointer',
  },
  list: {
    width: '100%', maxWidth: 420,
    background: '#1e293b',
    borderRadius: 16, padding: '16px 20px',
    marginTop: 8,
  },
  listTitle: {
    fontSize: 11, fontWeight: 700, color: '#64748b',
    textTransform: 'uppercase', letterSpacing: 1, marginBottom: 10,
  },
  row: {
    display: 'flex', alignItems: 'center', gap: 12,
    padding: '10px 0',
    borderBottom: '1px solid #334155',
  },
  avatar: {
    width: 36, height: 36, borderRadius: '50%',
    background: '#76C043',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    fontWeight: 700, fontSize: 16,
    color: '#0f172a', flexShrink: 0,
  },
  rowName: { fontWeight: 600, fontSize: 14 },
  rowSub: { fontSize: 12, color: '#94a3b8', marginTop: 1 },
  rowTime: { fontSize: 13, color: '#64748b', flexShrink: 0 },
};
