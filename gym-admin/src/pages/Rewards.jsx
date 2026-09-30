import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Gift } from 'lucide-react';

const EMPTY = {
  title: '',
  description: '',
  reward_type: 'discount_percent',
  discount_percent: 10,
  discount_cents: 500,
  points_cost: 100,
  min_visits: 4,
  active: true,
};

function labelFor(reward) {
  if (reward.reward_type === 'discount_percent') return `${reward.discount_percent}% έκπτωση`;
  if (reward.reward_type === 'discount_fixed') return `${((reward.discount_cents || 0) / 100).toFixed(2)}€ έκπτωση`;
  return 'Ειδική προσφορά';
}

export default function Rewards() {
  const [rewards, setRewards] = useState([]);
  const [redemptions, setRedemptions] = useState([]);
  const [form, setForm] = useState(EMPTY);
  const [saving, setSaving] = useState(false);

  async function load() {
    const r = await api.get('/loyalty/admin');
    setRewards(r.data.rewards || []);
    setRedemptions(r.data.redemptions || []);
  }

  useEffect(() => { load().catch(() => toast.error('Σφάλμα φόρτωσης')); }, []);

  async function save(e) {
    e.preventDefault();
    setSaving(true);
    try {
      await api.post('/loyalty/admin', {
        ...form,
        discount_cents: Math.round(Number(form.discount_cents) || 0),
      });
      setForm(EMPTY);
      toast.success('Η προσφορά αποθηκεύτηκε');
      await load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  }

  async function deactivate(id) {
    try {
      await api.delete(`/loyalty/admin/${id}`);
      await load();
    } catch {
      toast.error('Σφάλμα');
    }
  }

  return (
    <Layout title="Προγράμματα επιβράβευσης">
      <p style={{ color: 'var(--text-2)', marginTop: -8, marginBottom: 18, maxWidth: 720 }}>
        Οι πόντοι μαζεύονται με κάθε παρουσία. Εδώ ορίζεις εκπτώσεις και προσφορές μόνο για όσους έχουν αρκετές επισκέψεις ή πόντους. Η έκπτωση εφαρμόζεται στην επόμενη drop-in κράτηση.
      </p>

      <form className="card" onSubmit={save} style={{ marginBottom: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 700, marginBottom: 12 }}>
          <Gift size={16} /> Νέα προσφορά
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr 1fr', gap: 10 }}>
          <input className="form-input" placeholder="Τίτλος" value={form.title} required onChange={e => setForm(f => ({ ...f, title: e.target.value }))} />
          <select className="form-input" value={form.reward_type} onChange={e => setForm(f => ({ ...f, reward_type: e.target.value }))}>
            <option value="discount_percent">Έκπτωση %</option>
            <option value="discount_fixed">Έκπτωση σε ευρώ</option>
            <option value="offer">Ειδική προσφορά</option>
          </select>
          {form.reward_type === 'discount_percent' && (
            <input className="form-input" type="number" min="1" max="100" value={form.discount_percent} onChange={e => setForm(f => ({ ...f, discount_percent: Number(e.target.value) }))} />
          )}
          {form.reward_type === 'discount_fixed' && (
            <input className="form-input" type="number" min="0" step="1" placeholder="Λεπτά, 500 = 5€" value={form.discount_cents} onChange={e => setForm(f => ({ ...f, discount_cents: Number(e.target.value) }))} />
          )}
          {form.reward_type === 'offer' && <div />}
        </div>
        <input className="form-input" placeholder="Περιγραφή για το μέλος" value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} style={{ marginTop: 10 }} />
        <div style={{ display: 'flex', gap: 10, marginTop: 10 }}>
          <label style={{ flex: 1, fontSize: '0.8rem', color: 'var(--text-3)' }}>
            Πόντοι που ξοδεύει
            <input className="form-input" type="number" min="0" value={form.points_cost} onChange={e => setForm(f => ({ ...f, points_cost: Number(e.target.value) }))} />
          </label>
          <label style={{ flex: 1, fontSize: '0.8rem', color: 'var(--text-3)' }}>
            Ελάχιστες παρουσίες / 30 ημέρες
            <input className="form-input" type="number" min="0" value={form.min_visits} onChange={e => setForm(f => ({ ...f, min_visits: Number(e.target.value) }))} />
          </label>
          <button className="btn btn-primary" disabled={saving} style={{ alignSelf: 'end' }}>{saving ? 'Αποθήκευση…' : 'Προσθήκη'}</button>
        </div>
      </form>

      <div className="card" style={{ marginBottom: 20 }}>
        <div style={{ fontWeight: 700, marginBottom: 12 }}>Ενεργές προσφορές</div>
        {rewards.filter(r => r.active).length === 0 ? (
          <div className="text-muted">Δεν υπάρχουν ακόμα προσφορές.</div>
        ) : rewards.filter(r => r.active).map(r => (
          <div key={r.id} style={{ display: 'flex', justifyContent: 'space-between', gap: 12, padding: '10px 0', borderTop: '1px solid var(--border)' }}>
            <div>
              <div style={{ fontWeight: 700 }}>{r.title}</div>
              <div style={{ color: 'var(--text-3)', fontSize: '0.8rem' }}>
                {labelFor(r)} · {r.points_cost} πόντοι · {r.min_visits} παρουσίες
              </div>
            </div>
            <button className="btn btn-secondary btn-sm" onClick={() => deactivate(r.id)}>Απενεργοποίηση</button>
          </div>
        ))}
      </div>

      <div className="card">
        <div style={{ fontWeight: 700, marginBottom: 12 }}>Εξαργυρώσεις</div>
        {redemptions.length === 0 ? <div className="text-muted">Καμία ακόμα.</div> : (
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.84rem' }}>
            <tbody>
              {redemptions.map(r => (
                <tr key={r.id} style={{ borderTop: '1px solid var(--border)' }}>
                  <td style={{ padding: '8px 0' }}>{r.full_name || '—'}</td>
                  <td>{r.title}</td>
                  <td style={{ color: 'var(--text-3)' }}>{r.status === 'used' ? 'Χρησιμοποιήθηκε' : 'Ενεργή'}</td>
                  <td style={{ color: 'var(--text-3)' }}>{new Date(r.created_at).toLocaleDateString('el-GR')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </Layout>
  );
}
