import { useEffect, useState, useCallback, useRef } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { useNavigate } from 'react-router-dom';
import { Printer, Maximize2, ArrowLeft, Minimize2 } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import BrandLogo from '../components/BrandLogo';
import api from '../api/client';

function formatTime(iso) {
  return new Date(iso).toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' });
}

function sessionsLabel(c) {
  if (!c.total_sessions || c.total_sessions >= 9999) return 'Απεριόριστη';
  const remaining = Math.max(0, c.total_sessions - (c.used_sessions || 0));
  if (remaining === 0) return 'Δεν απομένουν συνεδρίες';
  return `${remaining} απομένουν`;
}

function flashSessionsLabel(c) {
  if (!c.total_sessions || c.total_sessions >= 9999) {
    return 'Απεριόριστη συνδρομή — check-in καταγράφηκε';
  }
  const remaining = Math.max(0, c.total_sessions - (c.used_sessions || 0));
  if (remaining === 0) return 'Check-in επιτυχές — δεν απομένουν άλλες συνεδρίες';
  return `Απομένουν ${remaining} συνεδρίες`;
}

export default function Kiosk() {
  const navigate = useNavigate();
  const { business } = useAuth();
  const bizId = business?.id;

  const [checkins, setCheckins] = useState([]);
  const [lastCheckin, setLastCheckin] = useState(null);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const lastSeenIdRef = useRef(null);
  const flashTimerRef = useRef(null);

  const qrValue = bizId
    ? JSON.stringify({ action: 'checkin', bizId })
    : '';

  const loadCheckins = useCallback(async () => {
    if (!bizId) return;
    try {
      const res = await api.get(`/booking/${bizId}/qr-checkins`);
      const fresh = res.data;
      if (fresh.length > 0 && fresh[0].id !== lastSeenIdRef.current) {
        lastSeenIdRef.current = fresh[0].id;
        setLastCheckin(fresh[0]);
        if (flashTimerRef.current) clearTimeout(flashTimerRef.current);
        flashTimerRef.current = setTimeout(() => setLastCheckin(null), 4000);
      }
      setCheckins(fresh);
    } catch (_) {}
  }, [bizId]);

  useEffect(() => {
    loadCheckins();
    const t = setInterval(loadCheckins, 5000);
    return () => {
      clearInterval(t);
      if (flashTimerRef.current) clearTimeout(flashTimerRef.current);
    };
  }, [loadCheckins]);

  useEffect(() => {
    const onFsChange = () => setIsFullscreen(!!document.fullscreenElement);
    document.addEventListener('fullscreenchange', onFsChange);
    return () => document.removeEventListener('fullscreenchange', onFsChange);
  }, []);

  const toggleFullscreen = async () => {
    try {
      if (document.fullscreenElement) {
        await document.exitFullscreen();
      } else {
        await document.documentElement.requestFullscreen();
      }
    } catch (_) {}
  };

  const handlePrint = () => window.print();

  const todayCheckins = checkins.filter(c => {
    const d = new Date(c.checked_in_at);
    const now = new Date();
    return d.toDateString() === now.toDateString();
  });

  return (
    <div className="kiosk-page" style={styles.page}>
      {/* Controls — hidden when printing */}
      <div className="kiosk-controls no-print" style={styles.controls}>
        <button type="button" style={styles.ctrlBtn} onClick={() => navigate('/')}>
          <ArrowLeft size={16} /> Panel
        </button>
        <button type="button" style={styles.ctrlBtn} onClick={handlePrint}>
          <Printer size={16} /> Εκτύπωση QR
        </button>
        <button type="button" style={styles.ctrlBtn} onClick={toggleFullscreen}>
          {isFullscreen ? <Minimize2 size={16} /> : <Maximize2 size={16} />}
          {isFullscreen ? 'Έξοδος' : 'Πλήρης οθόνη'}
        </button>
      </div>

      {/* Success flash — only on new check-in */}
      {lastCheckin && (
        <div className="no-print" style={styles.flash}>
          <span style={{ fontSize: 32 }}>✓</span>
          <div>
            <div style={{ fontWeight: 700, fontSize: 20 }}>{lastCheckin.full_name}</div>
            <div style={{ opacity: 0.85, fontSize: 14 }}>
              {flashSessionsLabel(lastCheckin)}
            </div>
          </div>
        </div>
      )}

      <div className="kiosk-print-area">
        <div style={styles.header}>
          <BrandLogo variant="kiosk" logoUrl={business?.logo_url} />
          <div style={styles.subtitle}>Σκανάρετε για check-in</div>
        </div>

        <div style={styles.qrWrap} className="kiosk-qr-wrap">
          {qrValue ? (
            <QRCodeSVG
              value={qrValue}
              size={280}
              bgColor="#ffffff"
              fgColor="#0f172a"
              level="M"
            />
          ) : (
            <div style={{ color: '#64748b' }}>Φόρτωση...</div>
          )}
        </div>

        <div style={styles.hint}>Ανοίξτε το Handstand App → Check-in</div>
      </div>

      {todayCheckins.length > 0 && (
        <div className="no-print" style={styles.list}>
          <div style={styles.listTitle}>Πρόσφατα check-ins σήμερα</div>
          {todayCheckins.slice(0, 8).map(c => (
            <div key={c.id} style={styles.listRow}>
              <div style={styles.listAvatar}>
                {c.full_name?.charAt(0).toUpperCase()}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 600 }}>{c.full_name}</div>
                <div style={{ fontSize: 12, color: '#94a3b8' }}>
                  {sessionsLabel(c)}
                </div>
              </div>
              <div style={{ fontSize: 13, color: '#64748b' }}>
                {formatTime(c.checked_in_at)}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

const styles = {
  page: {
    minHeight: '100vh',
    background: '#0f172a',
    color: '#f8fafc',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '40px 24px',
    fontFamily: 'system-ui, sans-serif',
    position: 'relative',
  },
  controls: {
    position: 'fixed',
    top: 16,
    right: 16,
    display: 'flex',
    gap: 8,
    zIndex: 200,
    flexWrap: 'wrap',
    justifyContent: 'flex-end',
    maxWidth: '100%',
  },
  ctrlBtn: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: 6,
    padding: '8px 14px',
    borderRadius: 10,
    border: '1px solid #334155',
    background: 'rgba(30, 41, 59, 0.92)',
    color: '#e2e8f0',
    fontSize: 13,
    fontWeight: 500,
    cursor: 'pointer',
    backdropFilter: 'blur(8px)',
  },
  flash: {
    position: 'fixed',
    top: 24,
    left: '50%',
    transform: 'translateX(-50%)',
    background: '#22c55e',
    color: '#fff',
    borderRadius: 16,
    padding: '16px 28px',
    display: 'flex',
    alignItems: 'center',
    gap: 16,
    boxShadow: '0 8px 30px rgba(0,0,0,0.4)',
    zIndex: 100,
    animation: 'kioskSlideDown 0.3s ease',
    maxWidth: 'calc(100% - 32px)',
  },
  header: {
    textAlign: 'center',
    marginBottom: 32,
    width: '100%',
    maxWidth: 420,
  },
  subtitle: {
    fontSize: 18,
    color: '#94a3b8',
    marginTop: 6,
  },
  qrWrap: {
    background: '#ffffff',
    borderRadius: 24,
    padding: 24,
    boxShadow: '0 0 60px rgba(99,102,241,0.3)',
    marginBottom: 20,
  },
  hint: {
    color: '#64748b',
    fontSize: 14,
    marginBottom: 36,
    textAlign: 'center',
  },
  list: {
    width: '100%',
    maxWidth: 420,
    background: '#1e293b',
    borderRadius: 16,
    padding: '16px 20px',
  },
  listTitle: {
    fontSize: 13,
    fontWeight: 600,
    color: '#64748b',
    textTransform: 'uppercase',
    letterSpacing: 1,
    marginBottom: 12,
  },
  listRow: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    padding: '10px 0',
    borderBottom: '1px solid #334155',
  },
  listAvatar: {
    width: 36,
    height: 36,
    borderRadius: '50%',
    background: '#76C043',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontWeight: 700,
    fontSize: 16,
    flexShrink: 0,
  },
};
