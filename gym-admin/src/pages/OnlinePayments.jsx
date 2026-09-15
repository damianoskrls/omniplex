import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { CreditCard, FileText, RotateCcw, Eye, EyeOff } from 'lucide-react';

export default function OnlinePayments() {
  const biz = JSON.parse(localStorage.getItem('gym_admin_business') || '{}');
  const bizId = biz.id;

  const [loading, setLoading] = useState(true);
  const [stripe, setStripe] = useState({ secret_key: '', publishable_key: '', webhook_secret: '', is_active: false });
  const [showSecret, setShowSecret] = useState(false);
  const [savingStripe, setSavingStripe] = useState(false);
  const [mydata, setMydata] = useState({
    is_enabled: false, aade_user_id: '', aade_subscription_key: '',
    vat_number: '', tax_authority: '', legal_name: '', address: '',
    is_production: false, invoice_type: '11.1', vat_category: 1,
  });
  const [savingMydata, setSavingMydata] = useState(false);

  useEffect(() => {
    api.get(`/payments-online/${bizId}/config`)
      .then(r => {
        const s = r.data.providers?.find(p => p.provider === 'stripe');
        if (s) setStripe(prev => ({ ...prev, is_active: s.is_active, publishable_key: s.publishable_key || '' }));
        if (r.data.mydata) setMydata(prev => ({ ...prev, ...r.data.mydata }));
      })
      .catch(() => toast.error('Σφάλμα φόρτωσης'))
      .finally(() => setLoading(false));
  }, [bizId]);

  const saveStripe = async () => {
    if (!stripe.secret_key || !stripe.publishable_key)
      return toast.error('Απαιτούνται secret key και publishable key');
    setSavingStripe(true);
    try {
      await api.put(`/payments-online/${bizId}/provider/stripe`, stripe);
      toast.success('Stripe αποθηκεύτηκε');
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
    finally { setSavingStripe(false); }
  };

  const saveMydata = async () => {
    setSavingMydata(true);
    try {
      await api.put(`/payments-online/${bizId}/mydata`, mydata);
      toast.success('myDATA αποθηκεύτηκε');
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
    finally { setSavingMydata(false); }
  };

  if (loading) return <Layout><div className="loading">Φόρτωση…</div></Layout>;

  return (
    <Layout>
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 44, height: 44, borderRadius: 14,
            background: 'linear-gradient(135deg,#eff6ff,#dbeafe)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#1d4ed8',
          }}>
            <CreditCard size={22} />
          </div>
          <div>
            <h1 className="page-title">Online Πληρωμές & myDATA</h1>
            <div className="text-muted" style={{ marginTop: 2 }}>Ρύθμιση Stripe και σύνδεση με AADE</div>
          </div>
        </div>
      </div>

      {/* Stripe */}
      <div className="card" style={{ marginBottom: 20 }}>
        <div className="card-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{
              width: 36, height: 36, borderRadius: 10,
              background: 'linear-gradient(135deg,#635bff20,#635bff10)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#635bff',
            }}>
              <CreditCard size={18} />
            </div>
            <span className="card-title">Stripe</span>
          </div>
        </div>

        <div className="form-grid-2">
          <div className="form-group">
            <label className="form-label">Publishable Key</label>
            <input className="form-input" placeholder="pk_live_…"
              value={stripe.publishable_key}
              onChange={e => setStripe({ ...stripe, publishable_key: e.target.value })} />
          </div>
          <div className="form-group">
            <label className="form-label">Secret Key</label>
            <div style={{ position: 'relative' }}>
              <input className="form-input" placeholder="sk_live_…"
                type={showSecret ? 'text' : 'password'}
                value={stripe.secret_key}
                onChange={e => setStripe({ ...stripe, secret_key: e.target.value })}
                style={{ paddingRight: 40 }} />
              <button onClick={() => setShowSecret(!showSecret)}
                style={{
                  position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)',
                  background: 'none', border: 'none', cursor: 'pointer', color: '#94a3b8', display: 'flex',
                }}>
                {showSecret ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </div>
        </div>

        <div className="form-group">
          <label className="form-label">Webhook Secret <span className="text-muted">(προαιρετικό)</span></label>
          <input className="form-input" placeholder="whsec_…" type="password"
            value={stripe.webhook_secret}
            onChange={e => setStripe({ ...stripe, webhook_secret: e.target.value })} />
          <div className="text-muted" style={{ marginTop: 6 }}>
            Webhook endpoint: <code style={{ fontSize: '0.8rem', background: '#f1f5f9', padding: '2px 6px', borderRadius: 4 }}>
              /api/payments-online/{bizId}/webhook/stripe
            </code>
          </div>
        </div>

        <div className="form-group">
          <label style={{ display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer' }}>
            <span className="toggle">
              <input type="checkbox" checked={!!stripe.is_active}
                onChange={e => setStripe({ ...stripe, is_active: e.target.checked })} />
              <span className="toggle-slider" />
            </span>
            <span style={{ fontWeight: 500, color: '#475569', fontSize: '0.875rem' }}>Ενεργοποίηση online πληρωμών</span>
          </label>
        </div>

        <button className="btn btn-primary" onClick={saveStripe} disabled={savingStripe}>
          {savingStripe ? 'Αποθήκευση…' : 'Αποθήκευση Stripe'}
        </button>
      </div>

      {/* myDATA */}
      <div className="card" style={{ marginBottom: 20 }}>
        <div className="card-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{
              width: 36, height: 36, borderRadius: 10,
              background: 'linear-gradient(135deg,#f0fdf420,#dcfce710)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#16a34a',
              border: '1px solid #dcfce7',
            }}>
              <FileText size={18} />
            </div>
            <span className="card-title">myDATA / AADE</span>
          </div>
        </div>

        <div className="form-group">
          <label style={{ display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer' }}>
            <span className="toggle">
              <input type="checkbox" checked={!!mydata.is_enabled}
                onChange={e => setMydata({ ...mydata, is_enabled: e.target.checked })} />
              <span className="toggle-slider" />
            </span>
            <span style={{ fontWeight: 500, color: '#475569', fontSize: '0.875rem' }}>Ενεργοποίηση myDATA</span>
          </label>
        </div>

        <div className="form-grid-2">
          <div className="form-group">
            <label className="form-label">AADE User ID</label>
            <input className="form-input" value={mydata.aade_user_id || ''}
              onChange={e => setMydata({ ...mydata, aade_user_id: e.target.value })} />
          </div>
          <div className="form-group">
            <label className="form-label">Subscription Key</label>
            <input className="form-input" type="password" value={mydata.aade_subscription_key || ''}
              onChange={e => setMydata({ ...mydata, aade_subscription_key: e.target.value })} />
          </div>
        </div>

        <div className="form-grid-2">
          <div className="form-group">
            <label className="form-label">ΑΦΜ</label>
            <input className="form-input" value={mydata.vat_number || ''}
              onChange={e => setMydata({ ...mydata, vat_number: e.target.value })} />
          </div>
          <div className="form-group">
            <label className="form-label">ΔΟΥ</label>
            <input className="form-input" value={mydata.tax_authority || ''}
              onChange={e => setMydata({ ...mydata, tax_authority: e.target.value })} />
          </div>
        </div>

        <div className="form-group">
          <label className="form-label">Επωνυμία</label>
          <input className="form-input" value={mydata.legal_name || ''}
            onChange={e => setMydata({ ...mydata, legal_name: e.target.value })} />
        </div>

        <div className="form-group">
          <label className="form-label">Διεύθυνση</label>
          <input className="form-input" value={mydata.address || ''}
            onChange={e => setMydata({ ...mydata, address: e.target.value })} />
        </div>

        <div style={{ display: 'flex', gap: 16, alignItems: 'flex-end', flexWrap: 'wrap', marginBottom: 16 }}>
          <div className="form-group" style={{ margin: 0 }}>
            <label className="form-label">Κατηγορία ΦΠΑ</label>
            <select className="form-select" value={mydata.vat_category}
              onChange={e => setMydata({ ...mydata, vat_category: Number(e.target.value) })}>
              <option value={1}>1 — 24%</option>
              <option value={2}>2 — 13%</option>
              <option value={3}>3 — 6%</option>
              <option value={8}>8 — 0%</option>
            </select>
          </div>
          <label style={{ display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer', paddingBottom: 2 }}>
            <span className="toggle">
              <input type="checkbox" checked={!!mydata.is_production}
                onChange={e => setMydata({ ...mydata, is_production: e.target.checked })} />
              <span className="toggle-slider" />
            </span>
            <span style={{ fontWeight: 500, color: '#475569', fontSize: '0.875rem' }}>
              Production <span className="text-muted">(αλλιώς sandbox)</span>
            </span>
          </label>
        </div>

        <button className="btn btn-primary" onClick={saveMydata} disabled={savingMydata}>
          {savingMydata ? 'Αποθήκευση…' : 'Αποθήκευση myDATA'}
        </button>
      </div>

      {/* Resubmit hint */}
      <div className="card">
        <div className="card-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <RotateCcw size={16} style={{ color: '#64748b' }} />
            <span className="card-title" style={{ fontSize: '0.9rem' }}>Επανυποβολή στο myDATA</span>
          </div>
        </div>
        <p className="text-muted">Για πληρωμές που δεν στάλθηκαν στο myDATA, χρησιμοποίησε το endpoint:</p>
        <code style={{ display: 'block', marginTop: 8, fontSize: '0.8rem', background: '#f1f5f9', padding: '10px 14px', borderRadius: 8, color: '#475569' }}>
          POST /api/payments-online/{bizId}/mydata/resubmit/:paymentId
        </code>
      </div>
    </Layout>
  );
}
