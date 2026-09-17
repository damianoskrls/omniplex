import { useEffect, useRef, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';

const API_BASE = import.meta.env.VITE_API_URL ?? 'https://passionate-grace-production-98ad.up.railway.app';
import {
  ArrowLeft, Save, Upload, Copy, Smartphone, ExternalLink,
  Key, Eye, EyeOff, RefreshCw, ShoppingBag, CreditCard,
  Apple, Dumbbell, Scissors, Sparkles, Building2, Check, Euro,
} from 'lucide-react';

const ALL_FEATURES = [
  { key: 'feature_online_booking',      label: 'Online Κρατήσεις',      desc: 'Κράτηση μέσω app',           plans: ['starter','pro','enterprise'] },
  { key: 'feature_loyalty_points',      label: 'Loyalty Points',         desc: 'Πόντοι & επιβράβευση',       plans: ['pro','enterprise'] },
  { key: 'feature_memberships',         label: 'Συνδρομές',              desc: 'Πακέτα / μηνιαίες χρεώσεις', plans: ['pro','enterprise'] },
  { key: 'feature_waitlist',            label: 'Λίστα Αναμονής',         desc: 'Αυτόματη διαχείριση θέσεων', plans: ['pro','enterprise'] },
  { key: 'feature_nutrition',           label: 'Διατροφή',               desc: 'Μονάδα διατροφολόγου',       plans: ['pro','enterprise'] },
  { key: 'feature_marketplace',         label: 'Marketplace',            desc: 'Πώληση προϊόντων',           plans: ['pro','enterprise'] },
  { key: 'feature_online_payments',     label: 'Online Πληρωμές',        desc: 'Stripe / online checkout',    plans: ['enterprise'] },
  { key: 'feature_pos_integration',     label: 'POS Integration',        desc: 'Σύνδεση με ταμειακή',        plans: ['enterprise'] },
  { key: 'feature_multi_location',      label: 'Multi Location',         desc: 'Πολλαπλά υποκαταστήματα',    plans: ['enterprise'] },
  { key: 'feature_video_consultations', label: 'Video Συνεδρίες',        desc: 'Video call ραντεβού',         plans: ['enterprise'] },
];

const BUSINESS_TYPES = [
  { value: 'gym',              label: 'Γυμναστήριο',          icon: Dumbbell },
  { value: 'aesthetic',        label: 'Κέντρο Αισθητικής',    icon: Sparkles },
  { value: 'salon',            label: 'Κομμωτήριο',           icon: Scissors },
  { value: 'barbershop',       label: 'Barbershop',            icon: Scissors },
  { value: 'spa',              label: 'Spa / Wellness',        icon: Apple },
  { value: 'pilates',          label: 'Pilates / Yoga',        icon: Dumbbell },
  { value: 'physiotherapy',    label: 'Φυσικοθεραπεία',       icon: Building2 },
  { value: 'personal_training', label: 'Personal Training',   icon: Dumbbell },
];

const DEFAULT_LABELS_MAP = {
  gym:              { book_cta: 'Κράτηση', staff_noun: 'Γυμναστής', service_noun: 'Υπηρεσία', appointment_noun: 'Session', loyalty_label: 'Πόντοι' },
  aesthetic:        { book_cta: 'Κλείσε Ραντεβού', staff_noun: 'Τεχνικός', service_noun: 'Θεραπεία', appointment_noun: 'Ραντεβού', loyalty_label: 'Πόντοι Ομορφιάς' },
  salon:            { book_cta: 'Κλείσε Ραντεβού', staff_noun: 'Κομμωτής', service_noun: 'Υπηρεσία', appointment_noun: 'Ραντεβού', loyalty_label: 'Beauty Points' },
  barbershop:       { book_cta: 'Κλείσε Ραντεβού', staff_noun: 'Barber', service_noun: 'Κούρεμα', appointment_noun: 'Ραντεβού', loyalty_label: 'Loyalty Points' },
  spa:              { book_cta: 'Κράτηση', staff_noun: 'Θεραπευτής', service_noun: 'Θεραπεία', appointment_noun: 'Reservation', loyalty_label: 'Wellness Points' },
  pilates:          { book_cta: 'Κράτηση Μαθήματος', staff_noun: 'Εκπαιδευτής', service_noun: 'Μάθημα', appointment_noun: 'Session', loyalty_label: 'Πόντοι' },
  physiotherapy:    { book_cta: 'Κλείσε Ραντεβού', staff_noun: 'Φυσιοθεραπευτής', service_noun: 'Θεραπεία', appointment_noun: 'Ραντεβού', loyalty_label: 'Πόντοι' },
  personal_training: { book_cta: 'Κράτηση Προπόνησης', staff_noun: 'Trainer', service_noun: 'Προπόνηση', appointment_noun: 'Session', loyalty_label: 'Πόντοι' },
};

const LABEL_KEYS = [
  { key: 'book_cta',          label: 'CTA Κράτησης',    placeholder: 'π.χ. Κλείσε Ραντεβού' },
  { key: 'staff_noun',        label: 'Προσωπικό',        placeholder: 'π.χ. Γυμναστής' },
  { key: 'service_noun',      label: 'Υπηρεσία',         placeholder: 'π.χ. Μάθημα' },
  { key: 'appointment_noun',  label: 'Ραντεβού',          placeholder: 'π.χ. Session' },
  { key: 'home_hero',         label: 'Hero Text',         placeholder: 'π.χ. Κράτησε εύκολα...' },
  { key: 'loyalty_label',     label: 'Πόντοι Loyalty',   placeholder: 'π.χ. Πόντοι' },
];

export default function TenantDetail() {
  const { id }     = useParams();
  const navigate   = useNavigate();

  const [data, setData]           = useState(null);
  const [config, setConfig]       = useState({});
  const [bizInfo, setBizInfo]     = useState({});
  const [labels, setLabels]       = useState({});
  const [saving, setSaving]       = useState(false);
  const [uploading, setUploading]     = useState(false);
  const [uploadingIcon, setUploadingIcon] = useState(false);
  const [newPwd, setNewPwd]           = useState('');
  const [showPwd, setShowPwd]         = useState(false);
  const [savingPwd, setSavingPwd]     = useState(false);
  const fileRef     = useRef();
  const iconFileRef = useRef();

  useEffect(() => {
    api.get(`/tenants/${id}`).then(r => {
      const d = r.data;
      setData(d);
      setBizInfo({ name: d.name, owner_email: d.owner_email || '', business_type: d.business_type, plan: d.plan });
      setConfig({
        app_name:                    d.app_name        || d.name || '',
        primary_color:               d.primary_color   || '#6200EE',
        secondary_color:             d.secondary_color || '#03DAC6',
        accent_color:                d.accent_color    || '#FF6D00',
        background_color:            d.background_color|| '#0D0D0D',
        surface_color:               d.surface_color   || '#1A1A2E',
        font_family:                 d.font_family     || 'Inter',
        feature_online_booking:      d.feature_online_booking      ?? 1,
        feature_loyalty_points:      d.feature_loyalty_points      ?? 0,
        feature_memberships:         d.feature_memberships         ?? 0,
        feature_waitlist:            d.feature_waitlist            ?? 0,
        feature_nutrition:           d.feature_nutrition           ?? 0,
        feature_marketplace:         d.feature_marketplace         ?? 0,
        feature_online_payments:     d.feature_online_payments     ?? 0,
        feature_pos_integration:     d.feature_pos_integration     ?? 0,
        feature_multi_location:      d.feature_multi_location      ?? 0,
        feature_video_consultations: d.feature_video_consultations ?? 0,
      });
      const lo = d.label_overrides;
      setLabels(typeof lo === 'string' ? JSON.parse(lo) : (lo || {}));
    }).catch(() => navigate('/tenants'));
  }, [id]);

  const handleSave = async () => {
    setSaving(true);
    try {
      await api.patch(`/tenants/${id}`, bizInfo);
      await api.patch(`/tenants/${id}/config`, { ...config, label_overrides: labels });
      toast.success('Αποθηκεύτηκε');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally { setSaving(false); }
  };

  const handleLogoUpload = async (file) => {
    if (!file) return;
    setUploading(true);
    const fd = new FormData();
    fd.append('logo', file);
    try {
      const r = await api.post(`/tenants/${id}/logo`, fd);
      setData(d => ({ ...d, logo_url: r.data.logo_url }));
      toast.success('Logo ανέβηκε');
    } catch { toast.error('Σφάλμα upload'); }
    finally { setUploading(false); }
  };

  const handleIconUpload = async (file) => {
    if (!file) return;
    setUploadingIcon(true);
    const fd = new FormData();
    fd.append('icon', file);
    try {
      const r = await api.post(`/tenants/${id}/icon`, fd);
      setData(d => ({ ...d, icon_url: r.data.icon_url }));
      toast.success('Icon ανέβηκε');
    } catch { toast.error('Σφάλμα upload'); }
    finally { setUploadingIcon(false); }
  };

  const handleSetPassword = async () => {
    if (!newPwd || newPwd.length < 6) return toast.error('Τουλάχιστον 6 χαρακτήρες');
    setSavingPwd(true);
    try {
      await api.post(`/tenants/${id}/admin-password`, { password: newPwd });
      toast.success('Κωδικός ορίστηκε');
      setNewPwd('');
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
    finally { setSavingPwd(false); }
  };

  const applyDefaultLabels = () => {
    const defaults = DEFAULT_LABELS_MAP[bizInfo.business_type] || {};
    setLabels(l => ({ ...defaults, ...l }));
    toast.success('Default labels εφαρμόστηκαν');
  };

  const copyText = (text) => { navigator.clipboard.writeText(text); toast.success('Αντιγράφηκε'); };

  const cfg = (k) => config[k];
  const set = (k, v) => setConfig(c => ({ ...c, [k]: v }));
  const setFlag = (k, v) => setConfig(c => ({ ...c, [k]: v ? 1 : 0 }));

  const publicConfigUrl = `${API_BASE}/api/tenants/public/${data?.slug}`;
  const buildCmd = `python build-scripts/build_tenant.py --tenant-id ${data?.slug || id} --platform both --api-base ${API_BASE}`;

  if (!data) return <Layout title="Loading…"><div className="loading">Loading…</div></Layout>;

  const resolveMedia = (url) => {
    if (!url) return null;
    if (url.startsWith('http')) return `${url}?t=${Date.now()}`;
    return `${API_BASE}${url}?t=${Date.now()}`;
  };
  const logoSrc = resolveMedia(data.logo_url);
  const iconSrc = resolveMedia(data.icon_url);

  return (
    <Layout title={data.name}>
      <div className="page-header">
        <div style={{ display:'flex', alignItems:'center', gap:10 }}>
          {logoSrc && <img src={logoSrc} alt="" style={{ width:36, height:36, objectFit:'contain', borderRadius:8 }}/>}
          <button className="btn btn-secondary btn-sm" onClick={() => navigate('/tenants')}>
            <ArrowLeft size={14}/> Πίσω
          </button>
          <span style={{ fontWeight:700, fontSize:'1.1rem', color:'#1e293b' }}>{data.name}</span>
          <span className={`badge ${data.is_active ? 'badge-green' : 'badge-red'}`}>
            {data.is_active ? 'Ενεργό' : 'Ανενεργό'}
          </span>
        </div>
        <div style={{ display:'flex', gap:8 }}>
          <button className="btn btn-secondary" onClick={() => navigate(`/tenants/${id}/billing`)}>
            <Euro size={14}/> Billing & Στατιστικά
          </button>
          <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
            <Save size={14}/> {saving ? 'Αποθήκευση…' : 'Αποθήκευση αλλαγών'}
          </button>
        </div>
      </div>

      <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:16 }}>

        {/* ── Business Info ── */}
        <div className="card">
          <div className="card-header"><span className="card-title">Στοιχεία Επιχείρησης</span></div>
          <div className="form-group">
            <label className="form-label">Εμπορική Ονομασία</label>
            <input className="form-input" value={bizInfo.name || ''} onChange={e => setBizInfo(b => ({ ...b, name: e.target.value }))}/>
          </div>
          <div className="form-group">
            <label className="form-label">Email Admin</label>
            <input className="form-input" value={bizInfo.owner_email || ''} onChange={e => setBizInfo(b => ({ ...b, owner_email: e.target.value }))}/>
          </div>
          <div className="form-group">
            <label className="form-label">Τύπος Επιχείρησης</label>
            <select className="form-select" value={bizInfo.business_type || ''} onChange={e => setBizInfo(b => ({ ...b, business_type: e.target.value }))}>
              {BUSINESS_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">Plan</label>
            <select className="form-select" value={bizInfo.plan || 'starter'} onChange={e => setBizInfo(b => ({ ...b, plan: e.target.value }))}>
              <option value="starter">Starter</option>
              <option value="pro">Pro</option>
              <option value="enterprise">Enterprise</option>
            </select>
          </div>
          <div style={{ padding:'12px 0', borderTop:'1px solid #f1f5f9', marginTop:4 }}>
            <div className="text-muted" style={{ fontSize:'0.8rem', display:'flex', flexDirection:'column', gap:4 }}>
              <div><strong>Slug:</strong> {data.slug}</div>
              <div><strong>ID:</strong> {data.id}</div>
              <div><strong>Bundle:</strong> {data.bundle_id}</div>
            </div>
          </div>
        </div>

        {/* ── Logo + Icon + Admin Password ── */}
        <div style={{ display:'flex', flexDirection:'column', gap:16 }}>
          <div className="card">
            <div className="card-header"><span className="card-title">Λογότυπο & Icon</span></div>
            {/* Logo row */}
            <div style={{ display:'flex', gap:14, alignItems:'center', marginBottom:16 }}>
              <div style={{ width:80, height:80, borderRadius:12, border:'2px dashed #e2e8f0', background:'#f8fafc',
                display:'flex', alignItems:'center', justifyContent:'center', overflow:'hidden', flexShrink:0 }}>
                {logoSrc
                  ? <img src={logoSrc} alt="" style={{ width:'100%', height:'100%', objectFit:'contain' }}/>
                  : <Building2 size={30} style={{ color:'#cbd5e1' }}/>}
              </div>
              <div>
                <div style={{ fontSize:'0.8rem', fontWeight:600, color:'#475569', marginBottom:6 }}>Logo (οριζόντιο / κύριο)</div>
                <input ref={fileRef} type="file" accept="image/png,image/jpeg,image/webp,image/svg+xml" style={{ display:'none' }}
                  onChange={e => e.target.files[0] && handleLogoUpload(e.target.files[0])}/>
                <button className="btn btn-secondary btn-sm" onClick={() => fileRef.current.click()} disabled={uploading}>
                  <Upload size={13}/> {uploading ? 'Ανέβασμα…' : 'Ανέβασε Logo'}
                </button>
                <div className="text-muted" style={{ fontSize:'0.75rem', marginTop:4 }}>PNG / JPEG / WebP / SVG · max 5MB</div>
              </div>
            </div>
            {/* Divider */}
            <div style={{ borderTop:'1px solid #f1f5f9', marginBottom:16 }}/>
            {/* Icon row */}
            <div style={{ display:'flex', gap:14, alignItems:'center' }}>
              <div style={{ width:64, height:64, borderRadius:14, border:'2px dashed #e2e8f0', background:'#f8fafc',
                display:'flex', alignItems:'center', justifyContent:'center', overflow:'hidden', flexShrink:0 }}>
                {iconSrc
                  ? <img src={iconSrc} alt="" style={{ width:'100%', height:'100%', objectFit:'cover' }}/>
                  : <Smartphone size={26} style={{ color:'#cbd5e1' }}/>}
              </div>
              <div>
                <div style={{ fontSize:'0.8rem', fontWeight:600, color:'#475569', marginBottom:6 }}>App Icon (τετράγωνο)</div>
                <input ref={iconFileRef} type="file" accept="image/png,image/jpeg,image/webp,image/svg+xml" style={{ display:'none' }}
                  onChange={e => e.target.files[0] && handleIconUpload(e.target.files[0])}/>
                <button className="btn btn-secondary btn-sm" onClick={() => iconFileRef.current.click()} disabled={uploadingIcon}>
                  <Upload size={13}/> {uploadingIcon ? 'Ανέβασμα…' : 'Ανέβασε Icon'}
                </button>
                <div className="text-muted" style={{ fontSize:'0.75rem', marginTop:4 }}>PNG / JPEG / WebP / SVG · max 2MB · 1:1 αναλογία</div>
              </div>
            </div>
          </div>

          <div className="card">
            <div className="card-header"><span className="card-title"><Key size={15} style={{ verticalAlign:-2, marginRight:6 }}/>Admin Κωδικός</span></div>
            <div className="text-muted" style={{ fontSize:'0.82rem', marginBottom:12 }}>
              Ο ιδιοκτήτης συνδέεται στο <strong>gym-admin</strong> με email <code>{bizInfo.owner_email}</code> και αυτόν τον κωδικό.
            </div>
            <div style={{ display:'flex', gap:8, alignItems:'flex-end' }}>
              <div className="form-group" style={{ flex:1, margin:0 }}>
                <div style={{ position:'relative' }}>
                  <input className="form-input" type={showPwd ? 'text' : 'password'}
                    placeholder="Νέος κωδικός (min 6 χαρ.)"
                    value={newPwd} onChange={e => setNewPwd(e.target.value)}
                    onKeyDown={e => e.key === 'Enter' && handleSetPassword()}/>
                  <button onClick={() => setShowPwd(v => !v)} style={{ position:'absolute', right:10, top:'50%', transform:'translateY(-50%)', border:'none', background:'none', cursor:'pointer', color:'#64748b', display:'flex' }}>
                    {showPwd ? <EyeOff size={15}/> : <Eye size={15}/>}
                  </button>
                </div>
              </div>
              <button className="btn btn-primary btn-sm" onClick={handleSetPassword} disabled={savingPwd}>
                <Check size={13}/> {savingPwd ? '…' : 'Ορισμός'}
              </button>
            </div>
          </div>
        </div>

        {/* ── Branding ── */}
        <div className="card">
          <div className="card-header"><span className="card-title">Branding & Θέμα</span></div>

          <div className="form-group">
            <label className="form-label">Όνομα εφαρμογής (στο κινητό)</label>
            <input className="form-input" value={cfg('app_name') || ''} onChange={e => set('app_name', e.target.value)} placeholder="π.χ. Handstand"/>
          </div>

          <div className="form-group">
            <label className="form-label">Γραμματοσειρά</label>
            <select className="form-select" value={cfg('font_family') || 'Inter'} onChange={e => set('font_family', e.target.value)}>
              {['Inter','Roboto','Oswald','Playfair Display','Montserrat','Poppins','Lato','Nunito'].map(f => (
                <option key={f} value={f}>{f}</option>
              ))}
            </select>
          </div>

          {[
            { key:'primary_color',    label:'Primary Color',    desc:'Κύριο χρώμα (κουμπιά, πρωτεύοντα elements)' },
            { key:'secondary_color',  label:'Secondary Color',  desc:'Δευτερεύον χρώμα' },
            { key:'accent_color',     label:'Accent Color',     desc:'Τόνος έμφασης (badges, highlights)' },
            { key:'background_color', label:'Background',       desc:'Χρώμα φόντου εφαρμογής' },
            { key:'surface_color',    label:'Surface Color',    desc:'Χρώμα καρτών / surfaces' },
          ].map(({ key, label, desc }) => (
            <div className="form-group" key={key}>
              <label className="form-label">{label}</label>
              <div style={{ display:'flex', alignItems:'center', gap:8 }}>
                <div style={{ width:36, height:36, borderRadius:8, background: cfg(key) || '#000', border:'2px solid #e2e8f0', flexShrink:0 }}/>
                <input type="color" value={cfg(key) || '#000000'} onChange={e => set(key, e.target.value)}
                  style={{ width:44, height:36, border:'none', background:'none', cursor:'pointer', padding:0 }}/>
                <input className="form-input" value={cfg(key) || ''} onChange={e => set(key, e.target.value)}
                  style={{ flex:1, maxWidth:100 }} maxLength={7} placeholder="#RRGGBB"/>
                <span className="text-muted" style={{ fontSize:'0.75rem', flex:1 }}>{desc}</span>
              </div>
            </div>
          ))}

          {/* Live Preview */}
          <div style={{ marginTop:16, borderRadius:14, overflow:'hidden', boxShadow:'0 4px 20px rgba(0,0,0,0.12)' }}>
            <div style={{ background: cfg('background_color') || '#0D0D0D', padding:16 }}>
              <div style={{ fontFamily: cfg('font_family'), color:'#fff', fontWeight:700, fontSize:'0.9rem', marginBottom:8 }}>
                {cfg('app_name') || data.name}
              </div>
              <div style={{ display:'flex', gap:8 }}>
                <div style={{ padding:'6px 14px', background: cfg('primary_color'), color:'#fff', borderRadius:20, fontSize:'0.75rem', fontWeight:600 }}>
                  {labels.book_cta || 'Κράτηση'}
                </div>
                <div style={{ padding:'6px 12px', background: cfg('surface_color') || '#1A1A2E', color: cfg('accent_color') || '#FF6D00', borderRadius:20, fontSize:'0.75rem', fontWeight:600, border:`1px solid ${cfg('accent_color') || '#FF6D00'}` }}>
                  {labels.loyalty_label || 'Πόντοι'}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* ── Features ── */}
        <div className="card">
          <div className="card-header">
            <span className="card-title">Features</span>
            <span className="badge badge-blue">Plan: {bizInfo.plan}</span>
          </div>
          {ALL_FEATURES.map(f => (
            <div key={f.key} style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'10px 0', borderBottom:'1px solid #f1f5f9' }}>
              <div>
                <div style={{ fontWeight:600, fontSize:'0.875rem', color:'#1e293b' }}>{f.label}</div>
                <div className="text-muted" style={{ fontSize:'0.78rem' }}>{f.desc}</div>
              </div>
              <label className="toggle">
                <input type="checkbox" checked={!!cfg(f.key)} onChange={e => setFlag(f.key, e.target.checked)}/>
                <span className="toggle-slider"/>
              </label>
            </div>
          ))}

          {/* Flutter public config link */}
          <div style={{ marginTop:16, padding:12, background:'#f0fdf4', borderRadius:10, border:'1px solid #bbf7d0' }}>
            <div style={{ fontWeight:600, fontSize:'0.82rem', marginBottom:6, color:'#166534' }}>Flutter Public Config URL</div>
            <div style={{ display:'flex', gap:8, alignItems:'center' }}>
              <code style={{ fontSize:'0.72rem', color:'#15803d', flex:1, wordBreak:'break-all' }}>{publicConfigUrl}</code>
              <button className="btn btn-secondary btn-sm" onClick={() => copyText(publicConfigUrl)}>
                <Copy size={12}/>
              </button>
              <a className="btn btn-secondary btn-sm" href={publicConfigUrl} target="_blank" rel="noopener noreferrer">
                <ExternalLink size={12}/>
              </a>
            </div>
          </div>
        </div>

        {/* ── Label Overrides ── */}
        <div className="card">
          <div className="card-header">
            <span className="card-title">Label Overrides</span>
            <button className="btn btn-secondary btn-sm" onClick={applyDefaultLabels}>
              <RefreshCw size={12}/> Auto-fill από τύπο
            </button>
          </div>
          <div className="text-muted" style={{ fontSize:'0.8rem', marginBottom:14 }}>
            Αντικατάσταση κειμένων στην εφαρμογή ανάλογα με τον τύπο επιχείρησης.
          </div>
          {LABEL_KEYS.map(lk => (
            <div className="form-group" key={lk.key}>
              <label className="form-label">{lk.label}</label>
              <input className="form-input" placeholder={lk.placeholder}
                value={labels[lk.key] || ''}
                onChange={e => setLabels(l => ({ ...l, [lk.key]: e.target.value }))}/>
            </div>
          ))}
        </div>

        {/* ── Build / Deploy ── */}
        <div className="card">
          <div className="card-header"><span className="card-title"><Smartphone size={15} style={{ verticalAlign:-2, marginRight:6 }}/>White-label App</span></div>
          <div className="text-muted" style={{ marginBottom:16, fontSize:'0.85rem', lineHeight:1.6 }}>
            Η εφαρμογή <strong>ergonhub</strong> παίρνει δυναμικά τη διαμόρφωση από το API ({publicConfigUrl}).
            Κάθε client βλέπει το δικό του branding, χρώματα και λογότυπο.
          </div>

          <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:12, marginBottom:16 }}>
            {[
              { title:'Δυναμικό config (runtime)', items:['Flutter φορτώνει config από API', 'Ο user βάζει business slug', 'Branding εφαρμόζεται αμέσως', 'Δεν χρειάζεται rebuild'] },
              { title:'Static build (App Store)', items:['Build με tenant_config.json', 'Ξεχωριστό bundle ID / App Store listing', 'Βέλτιστη εμπειρία χρήστη', 'Χρειάζεται rebuild για αλλαγές'] },
            ].map(s => (
              <div key={s.title} style={{ padding:12, background:'#f8fafc', borderRadius:10, border:'1px solid #e2e8f0' }}>
                <div style={{ fontWeight:600, fontSize:'0.82rem', marginBottom:8 }}>{s.title}</div>
                <ul style={{ margin:0, paddingLeft:16, fontSize:'0.8rem', color:'#475569', lineHeight:1.7 }}>
                  {s.items.map(i => <li key={i}>{i}</li>)}
                </ul>
              </div>
            ))}
          </div>

          <div style={{ marginBottom:10, fontWeight:600, fontSize:'0.82rem' }}>Build command (static)</div>
          <pre style={{ background:'#0f172a', color:'#e2e8f0', padding:12, borderRadius:8, fontSize:'0.72rem', overflow:'auto', marginBottom:10 }}>{buildCmd}</pre>
          <div style={{ display:'flex', gap:8 }}>
            <button className="btn btn-secondary btn-sm" onClick={() => copyText(buildCmd)}>
              <Copy size={13}/> Αντιγραφή
            </button>
            <a className="btn btn-secondary btn-sm" href={`${API_BASE}/api/tenants/${data.slug}/build-config`} target="_blank" rel="noopener noreferrer">
              <ExternalLink size={13}/> Build Config JSON
            </a>
          </div>
        </div>

        {/* Admin credentials card */}
        <div className="card">
          <div className="card-header"><span className="card-title">Admin Panel Credentials</span></div>
          <div style={{ display:'flex', flexDirection:'column', gap:12 }}>
            {[
              { label:'Admin URL',   value: window.location.origin },
              { label:'Email',       value: bizInfo.owner_email || data.owner_email || '' },
              { label:'Business ID', value: data.id },
              { label:'Slug',        value: data.slug },
            ].map(({ label, value }) => (
              <div key={label} style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'8px 0', borderBottom:'1px solid #f1f5f9' }}>
                <span className="text-muted" style={{ fontSize:'0.82rem', width:100, flexShrink:0 }}>{label}</span>
                <code style={{ flex:1, fontSize:'0.8rem', color:'#0f172a' }}>{value}</code>
                <button className="btn btn-secondary btn-sm" style={{ flexShrink:0 }} onClick={() => copyText(value)}>
                  <Copy size={12}/>
                </button>
              </div>
            ))}
          </div>
          <div style={{ marginTop:16, padding:12, background:'#fef3c7', borderRadius:10, fontSize:'0.8rem', color:'#92400e' }}>
            💡 Ορίσε κωδικό από το πεδίο "Admin Κωδικός" πιο πάνω. Default (αν δεν οριστεί): <code>admin123</code>
          </div>
        </div>

      </div>
    </Layout>
  );
}
