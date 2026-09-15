import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Save, Send, Bell, Settings2, ImagePlus, X, AlertTriangle, ChevronRight } from 'lucide-react';
import { mediaUrl } from '../utils/media';
import { fmtDate } from '../utils/dates';

function daysLeft(validUntil) {
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const exp = new Date(validUntil); exp.setHours(0, 0, 0, 0);
  return Math.round((exp - today) / 86400000);
}

export default function Notifications() {
  const navigate = useNavigate();
  const [expiring, setExpiring] = useState([]);
  const [settings, setSettings] = useState({
    booking_reminder_24h: true,
    booking_reminder_1h: true,
    auto_payment_reminders: false,
    payment_reminder_days: 3,
    fcm_configured: false,
  });
  const [saving, setSaving] = useState(false);
  const [sending, setSending] = useState(false);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [audience, setAudience] = useState('all');
  const [imageUrl, setImageUrl] = useState('');
  const [uploadingImage, setUploadingImage] = useState(false);

  const load = () => {
    api.get('/client-admin/notification-settings')
      .then(r => setSettings(r.data))
      .catch(() => toast.error('Σφάλμα φόρτωσης ρυθμίσεων'));
    api.get('/client-admin/expiring-memberships')
      .then(r => setExpiring(r.data || []))
      .catch(() => {});
  };

  useEffect(() => { load(); }, []);

  const saveSettings = async () => {
    setSaving(true);
    try {
      const r = await api.patch('/client-admin/notification-settings', settings);
      setSettings(r.data);
      toast.success('Οι ρυθμίσεις αποθηκεύτηκαν');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  const uploadImage = async (file) => {
    if (!file) return;
    setUploadingImage(true);
    try {
      const form = new FormData();
      form.append('image', file);
      const r = await api.post('/client-admin/notifications/image', form, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      setImageUrl(r.data.image_url || '');
      toast.success('Η εικόνα ανέβηκε');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα ανεβάσματος');
    } finally {
      setUploadingImage(false);
    }
  };

  const sendBroadcast = async (e) => {
    e.preventDefault();
    if (!title.trim() || !body.trim()) {
      toast.error('Συμπλήρωσε τίτλο και κείμενο');
      return;
    }
    if (!window.confirm(`Να σταλεί η ανακοίνωση σε ${audience === 'active' ? 'ενεργούς' : 'όλους τους'} πελάτες;`)) return;
    setSending(true);
    try {
      const r = await api.post('/client-admin/notifications/broadcast', {
        title: title.trim(),
        body: body.trim(),
        audience,
        image_url: imageUrl || undefined,
      });
      toast.success(r.data.message || 'Εστάλη');
      if (r.data.push_note) toast(r.data.push_note, { icon: 'ℹ️' });
      setTitle('');
      setBody('');
      setImageUrl('');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα αποστολής');
    } finally {
      setSending(false);
    }
  };

  return (
    <Layout title="Ειδοποιήσεις">
      <div className="page-header">
        <div>
          <h2 className="page-title" style={{ margin: 0 }}>Push & ειδοποιήσεις πελατών</h2>
          <p className="text-muted" style={{ marginTop: 4, fontSize: '0.9rem' }}>
            Ανακοινώσεις, υπενθυμίσεις κρατήσεων και πληρωμών
          </p>
        </div>
      </div>

      {!settings.fcm_configured && (
        <div style={{
          marginBottom: 20, padding: 14, borderRadius: 10,
          background: '#fffbeb', border: '1px solid #fde68a', color: '#92400e', fontSize: '0.85rem',
        }}>
          <strong>FCM δεν είναι ρυθμισμένο στο API.</strong> Οι ειδοποιήσεις αποθηκεύονται και εμφανίζονται
          στην εφαρμογή πελατών. Για push στο κινητό (ακόμα και κλειστή εφαρμογή), πρόσθεσε{' '}
          <code>FCM_SERVER_KEY</code> στο <code>admin-api/.env</code> και Firebase στην εφαρμογή.
        </div>
      )}

      {/* Expiring memberships admin alert */}
      {expiring.length > 0 && (
        <div className="card" style={{ marginBottom: 20, borderLeft: '4px solid #f59e0b' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}>
            <AlertTriangle size={17} color="#d97706" />
            <span style={{ fontWeight: 700, color: '#92400e', fontSize: '0.95rem' }}>
              Συνδρομές που λήγουν σύντομα ({expiring.length})
            </span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
            {expiring.map(m => {
              const left = daysLeft(m.valid_until);
              const urgency = left === 0 ? '#ef4444' : left === 1 ? '#f97316' : '#d97706';
              const sessions_left = m.total_sessions - m.used_sessions;
              return (
                <button
                  key={m.membership_id}
                  type="button"
                  onClick={() => navigate(`/clients/${m.user_id}`)}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 12,
                    padding: '10px 0', background: 'none', border: 'none',
                    borderBottom: '1px solid #f1f5f9', cursor: 'pointer', textAlign: 'left',
                  }}
                  onMouseEnter={e => e.currentTarget.style.opacity = '0.75'}
                  onMouseLeave={e => e.currentTarget.style.opacity = '1'}
                >
                  <div style={{
                    width: 36, height: 36, borderRadius: '50%', flexShrink: 0,
                    background: '#e2e8f0', display: 'flex', alignItems: 'center',
                    justifyContent: 'center', fontWeight: 700, color: '#64748b', fontSize: 14,
                  }}>
                    {(m.full_name || '?').charAt(0).toUpperCase()}
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontWeight: 600, fontSize: '0.88rem', color: '#1e293b' }}>{m.full_name}</div>
                    <div style={{ fontSize: '0.76rem', color: '#64748b' }}>
                      {m.plan_name || m.service_name || '—'}
                      {m.phone ? ` · ${m.phone}` : ''}
                      {' · Λήγει '}{fmtDate(m.valid_until)}
                      {sessions_left > 0 && sessions_left < 9999 ? ` · ${sessions_left} συνεδρίες` : ''}
                      {m.plan_price ? ` · ${Number(m.plan_price).toFixed(0)}€` : ''}
                    </div>
                  </div>
                  <span style={{
                    background: urgency + '18', color: urgency, fontWeight: 700,
                    fontSize: '0.72rem', padding: '3px 9px', borderRadius: 20,
                    border: `1px solid ${urgency}40`, whiteSpace: 'nowrap', flexShrink: 0,
                  }}>
                    {left === 0 ? 'Σήμερα!' : left === 1 ? '1 μέρα' : `${left} μέρες`}
                  </span>
                  <ChevronRight size={14} color="#94a3b8" />
                </button>
              );
            })}
          </div>
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
        {/* Broadcast */}
        <div className="card">
          <div className="modal-title" style={{ marginBottom: 12, display: 'flex', alignItems: 'center', gap: 8 }}>
            <Send size={18} /> Νέα ανακοίνωση
          </div>
          <form onSubmit={sendBroadcast}>
            <div className="form-group">
              <label className="form-label">Παραλήπτες</label>
              <select className="form-select" value={audience} onChange={e => setAudience(e.target.value)}>
                <option value="all">Όλοι οι πελάτες</option>
                <option value="active">Μόνο ενεργοί πελάτες</option>
              </select>
            </div>
            <div className="form-group">
              <label className="form-label">Τίτλος</label>
              <input
                className="form-input"
                value={title}
                onChange={e => setTitle(e.target.value)}
                placeholder="π.χ. Αλλαγή ωραρίου"
                maxLength={120}
              />
            </div>
            <div className="form-group">
              <label className="form-label">Μήνυμα</label>
              <textarea
                className="form-input"
                rows={5}
                value={body}
                onChange={e => setBody(e.target.value)}
                placeholder="Το κείμενο που θα δουν οι πελάτες..."
              />
            </div>
            <div className="form-group">
              <label className="form-label">Εικόνα event (προαιρετικά)</label>
              {imageUrl ? (
                <div style={{ position: 'relative', marginBottom: 8 }}>
                  <img
                    src={mediaUrl(imageUrl)}
                    alt=""
                    style={{ width: '100%', maxHeight: 200, objectFit: 'cover', borderRadius: 10 }}
                  />
                  <button
                    type="button"
                    className="btn btn-secondary btn-sm"
                    style={{ position: 'absolute', top: 8, right: 8 }}
                    onClick={() => setImageUrl('')}
                  >
                    <X size={14} /> Αφαίρεση
                  </button>
                </div>
              ) : (
                <label className="btn btn-secondary" style={{ cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                  <ImagePlus size={14} />
                  {uploadingImage ? 'Ανέβασμα...' : 'Επιλογή εικόνας'}
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp,image/gif"
                    style={{ display: 'none' }}
                    disabled={uploadingImage}
                    onChange={e => {
                      const f = e.target.files?.[0];
                      if (f) uploadImage(f);
                      e.target.value = '';
                    }}
                  />
                </label>
              )}
              <div className="text-muted" style={{ fontSize: '0.78rem', marginTop: 6 }}>
                Ιδανικό για events, προσφορές ή ανακοινώσεις με poster
              </div>
            </div>
            <button type="submit" className="btn btn-primary" disabled={sending}>
              <Send size={14} /> {sending ? 'Αποστολή...' : 'Αποστολή σε πελάτες'}
            </button>
          </form>
        </div>

        {/* Settings */}
        <div className="card">
          <div className="modal-title" style={{ marginBottom: 12, display: 'flex', alignItems: 'center', gap: 8 }}>
            <Settings2 size={18} /> Αυτόματες υπενθυμίσεις
          </div>

          <label style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14, cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={settings.booking_reminder_24h}
              onChange={e => setSettings(s => ({ ...s, booking_reminder_24h: e.target.checked }))}
            />
            <div>
              <div style={{ fontWeight: 600, fontSize: '0.9rem' }}>1 μέρα πριν την προπόνηση</div>
              <div className="text-muted" style={{ fontSize: '0.78rem' }}>Υπενθύμιση 24 ώρες πριν την κράτηση</div>
            </div>
          </label>

          <label style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14, cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={settings.booking_reminder_1h}
              onChange={e => setSettings(s => ({ ...s, booking_reminder_1h: e.target.checked }))}
            />
            <div>
              <div style={{ fontWeight: 600, fontSize: '0.9rem' }}>1 ώρα πριν την προπόνηση</div>
              <div className="text-muted" style={{ fontSize: '0.78rem' }}>Προετοιμασία + ώρα ραντεβού</div>
            </div>
          </label>

          <hr style={{ border: 'none', borderTop: '1px solid #e2e8f0', margin: '16px 0' }} />

          <label style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14, cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={settings.auto_payment_reminders}
              onChange={e => setSettings(s => ({ ...s, auto_payment_reminders: e.target.checked }))}
            />
            <div>
              <div style={{ fontWeight: 600, fontSize: '0.9rem' }}>Αυτόματες υπενθυμίσεις πληρωμών</div>
              <div className="text-muted" style={{ fontSize: '0.78rem' }}>
                Αποστολή πριν τη λήξη πακέτου ή οφειλής (χωρίς χειροκίνητο κουμπί)
              </div>
            </div>
          </label>

          <div className="form-group">
            <label className="form-label">Ημέρες πριν τη λήξη πληρωμής / πακέτου</label>
            <input
              type="number"
              className="form-input"
              min={0}
              max={60}
              value={settings.payment_reminder_days}
              onChange={e => setSettings(s => ({ ...s, payment_reminder_days: Number(e.target.value) }))}
              style={{ maxWidth: 120 }}
            />
          </div>

          <button type="button" className="btn btn-primary" onClick={saveSettings} disabled={saving}>
            <Save size={14} /> {saving ? 'Αποθήκευση...' : 'Αποθήκευση ρυθμίσεων'}
          </button>

          <div style={{ marginTop: 20, padding: 12, background: '#f8fafc', borderRadius: 8, fontSize: '0.78rem', color: '#64748b' }}>
            <Bell size={14} style={{ verticalAlign: -2, marginRight: 4 }} />
            Οι αυτόματες ειδοποιήσεις ελέγχονται κάθε λεπτό από το API. Χειροκίνητες υπενθυμίσεις
            παραμένουν διαθέσιμες στη σελίδα <strong>Πληρωμές</strong>.
          </div>
        </div>
      </div>
    </Layout>
  );
}
