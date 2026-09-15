import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { ListOrdered, Save } from 'lucide-react';

export default function WaitlistConfig() {
  const biz = JSON.parse(localStorage.getItem('gym_admin_business') || '{}');
  const bizId = biz.id;

  const [cfg, setCfg] = useState({
    waitlist_mode: 'first_come',
    waitlist_offer_minutes: 15,
    waitlist_cutoff_hours: 2,
    waitlist_sms: false,
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.get(`/business/${bizId}/waitlist-config`)
      .then(r => setCfg(prev => ({ ...prev, ...r.data })))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [bizId]);

  const save = async () => {
    setSaving(true);
    try {
      await api.patch(`/business/${bizId}/waitlist-config`, {
        waitlist_mode: cfg.waitlist_mode,
        waitlist_offer_minutes: Number(cfg.waitlist_offer_minutes),
        waitlist_cutoff_hours: Number(cfg.waitlist_cutoff_hours),
        waitlist_sms: cfg.waitlist_sms ? 1 : 0,
      });
      toast.success('Αποθηκεύτηκε');
    } catch { toast.error('Σφάλμα αποθήκευσης'); }
    finally { setSaving(false); }
  };

  if (loading) return <Layout><div className="loading">Φόρτωση…</div></Layout>;

  return (
    <Layout>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 44, height: 44, borderRadius: 14,
            background: 'linear-gradient(135deg,#f0fdf4,#dcfce7)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#16a34a',
          }}>
            <ListOrdered size={22} />
          </div>
          <div>
            <h1 className="page-title">Λίστα Αναμονής</h1>
            <div className="text-muted" style={{ marginTop: 2 }}>Πώς προωθούνται οι θέσεις όταν ελευθερωθούν</div>
          </div>
        </div>
      </div>

      <div className="card" style={{ maxWidth: 580 }}>
        <div className="form-group">
          <label className="form-label" style={{ marginBottom: 12 }}>Λειτουργία προώθησης</label>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {[
              {
                value: 'first_come',
                label: 'Πρώτος ήρθε πρώτος εξυπηρετήθηκε',
                desc: 'Ειδοποίηση σε όλη τη λίστα — πρώτος αποδέχεται παίρνει τη θέση.',
              },
              {
                value: 'priority',
                label: 'Σειρά προτεραιότητας με hold',
                desc: 'Ειδοποίηση με σειρά — κάθε μέλος έχει X λεπτά για να αποδεχτεί.',
              },
            ].map(opt => (
              <label key={opt.value} style={{
                display: 'flex', gap: 12, padding: '14px 16px', borderRadius: 12,
                border: `2px solid ${cfg.waitlist_mode === opt.value ? 'var(--hs-primary)' : '#e2e8f0'}`,
                background: cfg.waitlist_mode === opt.value ? 'rgba(118,192,67,0.06)' : '#fff',
                cursor: 'pointer', transition: 'all 0.15s',
              }}>
                <input type="radio" name="mode" value={opt.value}
                  checked={cfg.waitlist_mode === opt.value}
                  onChange={() => setCfg({ ...cfg, waitlist_mode: opt.value })}
                  style={{ marginTop: 2, accentColor: 'var(--hs-primary)' }} />
                <div>
                  <div style={{ fontWeight: 700, fontSize: '0.9rem', color: '#1e293b' }}>{opt.label}</div>
                  <div className="text-muted" style={{ marginTop: 3 }}>{opt.desc}</div>
                </div>
              </label>
            ))}
          </div>
        </div>

        {cfg.waitlist_mode === 'priority' && (
          <div className="form-group">
            <label className="form-label">Χρόνος hold (λεπτά)</label>
            <input type="number" min={1} max={120} className="form-input" style={{ maxWidth: 120 }}
              value={cfg.waitlist_offer_minutes}
              onChange={e => setCfg({ ...cfg, waitlist_offer_minutes: e.target.value })} />
            <div className="text-muted" style={{ marginTop: 4 }}>
              Μετά από τόσα λεπτά χωρίς αποδοχή, η θέση προσφέρεται στον επόμενο.
            </div>
          </div>
        )}

        <div className="form-group">
          <label className="form-label">Cutoff πριν το μάθημα (ώρες)</label>
          <input type="number" min={0} max={48} className="form-input" style={{ maxWidth: 120 }}
            value={cfg.waitlist_cutoff_hours}
            onChange={e => setCfg({ ...cfg, waitlist_cutoff_hours: e.target.value })} />
          <div className="text-muted" style={{ marginTop: 4 }}>
            Δεν γίνονται προωθήσεις X ώρες πριν το μάθημα.
          </div>
        </div>

        <div className="form-group">
          <label style={{ display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer' }}>
            <span className="toggle">
              <input type="checkbox"
                checked={!!cfg.waitlist_sms}
                onChange={e => setCfg({ ...cfg, waitlist_sms: e.target.checked })} />
              <span className="toggle-slider" />
            </span>
            <span style={{ fontWeight: 500, color: '#475569', fontSize: '0.875rem' }}>
              Αποστολή SMS ειδοποίησης (εκτός push)
            </span>
          </label>
        </div>

        <button className="btn btn-primary" onClick={save} disabled={saving}>
          <Save size={15} /> {saving ? 'Αποθήκευση…' : 'Αποθήκευση ρυθμίσεων'}
        </button>
      </div>
    </Layout>
  );
}
