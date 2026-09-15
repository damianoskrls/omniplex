import { useEffect, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import {
  ShoppingBag, Plus, Edit2, Trash2, Package, ClipboardList, X, Check,
  Store, Upload, Image, Tag, Truck, CreditCard,
} from 'lucide-react';

// ─── helpers ──────────────────────────────────────────────────
const API_BASE = 'http://localhost:3001';
function imgSrc(url) {
  if (!url) return null;
  return url.startsWith('/') ? `${API_BASE}${url}` : url;
}

const ORDER_STATUS = {
  pending:   { label: 'Εκκρεμεί',    cls: 'badge-yellow' },
  paid:      { label: 'Πληρώθηκε',   cls: 'badge-blue' },
  fulfilled: { label: 'Παραδόθηκε',  cls: 'badge-green' },
  cancelled: { label: 'Ακυρώθηκε',   cls: 'badge-red' },
  refunded:  { label: 'Επιστράφηκε', cls: 'badge-gray' },
};

// ─── ProductModal ─────────────────────────────────────────────
function ProductModal({ product: initProduct, categories, onClose, onSave, bizId }) {
  const [product, setProduct] = useState(initProduct || null);
  const [form, setForm] = useState(initProduct || {
    name: '', description: '', category: '', price_cents: '',
    stock: null, image_url: '', is_active: true,
    sku: '', weight_grams: '', notes: '', ingredients: '', usage_instructions: '',
  });
  const [priceStr, setPriceStr] = useState(initProduct ? (initProduct.price_cents / 100).toFixed(2) : '');
  const [saving, setSaving]     = useState(false);
  const [uploading, setUploading] = useState(false);
  const [saved, setSaved]       = useState(!!initProduct);
  const [pendingFile, setPendingFile] = useState(null);
  const [pendingPreview, setPendingPreview] = useState(null);
  const fileRef = useRef();

  const set = (field, val) => setForm(f => ({ ...f, [field]: val }));

  const uploadImage = async (file, productId) => {
    setUploading(true);
    try {
      const fd = new FormData();
      fd.append('image', file);
      const r = await api.post(`/marketplace/${bizId}/admin/products/${productId}/image`, fd);
      setForm(f => ({ ...f, image_url: r.data.url }));
      setProduct(p => ({ ...p, image_url: r.data.url }));
      toast.success('Εικόνα ανέβηκε');
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα upload'); }
    finally { setUploading(false); }
  };

  const handleFileSelect = (file) => {
    setPendingFile(file);
    const reader = new FileReader();
    reader.onload = e => setPendingPreview(e.target.result);
    reader.readAsDataURL(file);
  };

  const save = async () => {
    const price_cents = Math.round(parseFloat(priceStr || '0') * 100);
    if (!form.name || !price_cents) return toast.error('Απαιτούνται όνομα και τιμή');
    setSaving(true);
    try {
      const payload = {
        ...form, price_cents,
        stock: form.stock === '' || form.stock === null ? null : Number(form.stock),
        weight_grams: form.weight_grams === '' || form.weight_grams === null ? null : Number(form.weight_grams),
        sku: form.sku || null,
        notes: form.notes || null,
        ingredients: form.ingredients || null,
        usage_instructions: form.usage_instructions || null,
      };
      if (product?.id) {
        await api.patch(`/marketplace/${bizId}/admin/products/${product.id}`, payload);
        if (pendingFile) await uploadImage(pendingFile, product.id);
        onSave({ ...payload, id: product.id });
        toast.success('Αποθηκεύτηκε');
        onClose();
      } else {
        const r = await api.post(`/marketplace/${bizId}/admin/products`, payload);
        const newProd = { ...payload, id: r.data.id };
        setProduct(newProd);
        setSaved(true);
        if (pendingFile) {
          await uploadImage(pendingFile, r.data.id);
          onSave({ ...newProd, image_url: form.image_url });
          toast.success('Προϊόν δημιουργήθηκε με εικόνα');
          onClose();
        } else {
          onSave(newProd);
          toast.success('Προϊόν δημιουργήθηκε');
          onClose();
        }
      }
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
    finally { setSaving(false); }
  };

  const src = pendingPreview || imgSrc(form.image_url);

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" style={{ maxWidth: 640 }} onClick={e => e.stopPropagation()}>
        <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:20 }}>
          <h2 className="modal-title" style={{ margin:0 }}>
            {initProduct ? 'Επεξεργασία Προϊόντος' : 'Νέο Προϊόν'}
          </h2>
          <button onClick={onClose} style={{ border:'none', background:'#f1f5f9', borderRadius:8, padding:6, cursor:'pointer', color:'#64748b', display:'flex' }}>
            <X size={16}/>
          </button>
        </div>

        {/* Image upload */}
        <div className="form-group">
          <label className="form-label">Εικόνα προϊόντος</label>
          <div style={{ display:'flex', gap:14, alignItems:'flex-start' }}>
            <div style={{
              width:88, height:88, borderRadius:14, border:'2px dashed #e2e8f0',
              background:'#f8fafc', display:'flex', alignItems:'center', justifyContent:'center',
              overflow:'hidden', flexShrink:0, cursor:'pointer',
            }} onClick={() => fileRef.current.click()}>
              {src
                ? <img src={src} alt="" style={{ width:'100%', height:'100%', objectFit:'cover' }}/>
                : <Image size={30} style={{ color:'#cbd5e1' }}/>}
            </div>
            <div style={{ flex:1, display:'flex', flexDirection:'column', gap:8 }}>
              <input ref={fileRef} type="file" accept="image/*" style={{ display:'none' }}
                onChange={e => e.target.files[0] && handleFileSelect(e.target.files[0])}/>
              <button className="btn btn-secondary btn-sm" onClick={() => fileRef.current.click()} disabled={uploading}>
                <Upload size={13}/> {uploading ? 'Ανέβασμα…' : pendingFile ? 'Αλλαγή εικόνας' : 'Επίλεξε εικόνα'}
              </button>
              {pendingFile && !saved && (
                <span style={{ fontSize:'0.75rem', color:'#64748b' }}>Θα ανεβεί με την αποθήκευση</span>
              )}
              <input className="form-input" placeholder="ή βάλε URL εικόνας…"
                value={form.image_url || ''}
                onChange={e => set('image_url', e.target.value)}/>
            </div>
          </div>
        </div>

        <div className="form-group">
          <label className="form-label">Όνομα *</label>
          <input className="form-input" value={form.name} onChange={e => set('name', e.target.value)}/>
        </div>
        <div className="form-group">
          <label className="form-label">Περιγραφή</label>
          <textarea className="form-input" rows={2} value={form.description || ''}
            onChange={e => set('description', e.target.value)}/>
        </div>
        <div className="form-grid-2">
          <div className="form-group">
            <label className="form-label">Κατηγορία</label>
            <select className="form-select" value={form.category || ''} onChange={e => set('category', e.target.value)}>
              <option value="">— Χωρίς κατηγορία —</option>
              {categories.map(c => <option key={c.id} value={c.name}>{c.name}</option>)}
            </select>
          </div>
          <div className="form-group">
            <label className="form-label">Τιμή (€) *</label>
            <input type="number" min={0} step={0.01} className="form-input"
              value={priceStr} onChange={e => setPriceStr(e.target.value)}/>
          </div>
        </div>
        <div className="form-grid-2">
          <div className="form-group">
            <label className="form-label">Απόθεμα <span className="text-muted">(κενό = ∞)</span></label>
            <input type="number" min={0} className="form-input"
              value={form.stock ?? ''}
              onChange={e => set('stock', e.target.value === '' ? null : e.target.value)}/>
          </div>
          <div className="form-group">
            <label className="form-label">Κωδικός SKU</label>
            <input className="form-input" placeholder="π.χ. SUPP-001"
              value={form.sku || ''} onChange={e => set('sku', e.target.value)}/>
          </div>
        </div>
        <div className="form-group">
          <label className="form-label">Βάρος (γραμμάρια)</label>
          <input type="number" min={0} className="form-input" style={{ maxWidth:140 }}
            value={form.weight_grams ?? ''}
            onChange={e => set('weight_grams', e.target.value === '' ? null : e.target.value)}/>
        </div>
        <div className="form-group">
          <label className="form-label">Χαρακτηριστικά <span className="text-muted">(χρώμα, διαστάσεις, υλικό…)</span></label>
          <textarea className="form-input" rows={2} placeholder="π.χ. Χρώμα: Μαύρο, Διαστάσεις: 30×20cm, Υλικό: 100% Polyester"
            value={form.notes || ''} onChange={e => set('notes', e.target.value)}/>
        </div>
        <div className="form-group">
          <label className="form-label">Συστατικά <span className="text-muted">(για supplements / τρόφιμα)</span></label>
          <textarea className="form-input" rows={3} placeholder="π.χ. Whey Protein Concentrate 80%, Cocoa Powder, Sucralose…"
            value={form.ingredients || ''} onChange={e => set('ingredients', e.target.value)}/>
        </div>
        <div className="form-group">
          <label className="form-label">Τρόπος Χρήσης / Οδηγίες</label>
          <textarea className="form-input" rows={3} placeholder="π.χ. Διάλυσε 1 μέτρο (30g) σε 200-250ml νερό ή γάλα. Κατανάλωσε αμέσως μετά την άσκηση."
            value={form.usage_instructions || ''} onChange={e => set('usage_instructions', e.target.value)}/>
        </div>
        <div className="form-group">
          <label style={{ display:'flex', alignItems:'center', gap:10, cursor:'pointer' }}>
            <span className="toggle">
              <input type="checkbox" checked={!!form.is_active} onChange={e => set('is_active', e.target.checked)}/>
              <span className="toggle-slider"/>
            </span>
            <span style={{ fontWeight:500, color:'#475569', fontSize:'0.875rem' }}>Ενεργό</span>
          </label>
        </div>

        <div className="modal-footer">
          <button className="btn btn-secondary" onClick={onClose}>{saved && !initProduct ? 'Κλείσιμο' : 'Άκυρο'}</button>
          <button className="btn btn-primary" onClick={save} disabled={saving}>
            {saving ? 'Αποθήκευση…' : 'Αποθήκευση'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── InStoreModal ─────────────────────────────────────────────
function InStoreModal({ products, onClose, onSave }) {
  const [items, setItems]   = useState([{ product_id: '', qty: 1 }]);
  const [customer, setCustomer] = useState('');
  const [method, setMethod] = useState('cash');
  const [notes, setNotes]   = useState('');
  const [saving, setSaving] = useState(false);

  const addLine  = () => setItems(i => [...i, { product_id: '', qty: 1 }]);
  const updLine  = (idx, field, val) => setItems(i => i.map((l, j) => j === idx ? { ...l, [field]: val } : l));
  const delLine  = (idx) => setItems(i => i.filter((_, j) => j !== idx));

  const productMap = Object.fromEntries(products.map(p => [p.id, p]));
  const total = items.reduce((s, l) => {
    const p = productMap[l.product_id];
    return s + (p ? p.price_cents * (Number(l.qty) || 1) : 0);
  }, 0);

  const save = async () => {
    const valid = items.filter(l => l.product_id);
    if (!valid.length) return toast.error('Πρόσθεσε τουλάχιστον ένα προϊόν');
    setSaving(true);
    try {
      await onSave({ items: valid.map(l => ({ product_id: l.product_id, qty: Number(l.qty) || 1 })),
        customer_name: customer, payment_method: method, notes });
      onClose();
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
    finally { setSaving(false); }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" style={{ maxWidth:540 }} onClick={e => e.stopPropagation()}>
        <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:20 }}>
          <h2 className="modal-title" style={{ margin:0 }}>Πώληση στο κατάστημα</h2>
          <button onClick={onClose} style={{ border:'none', background:'#f1f5f9', borderRadius:8, padding:6, cursor:'pointer', color:'#64748b', display:'flex' }}>
            <X size={16}/>
          </button>
        </div>
        <div className="form-group">
          <label className="form-label">Προϊόντα</label>
          {items.map((line, idx) => (
            <div key={idx} style={{ display:'flex', gap:8, marginBottom:8, alignItems:'center' }}>
              <select className="form-select" style={{ flex:1 }}
                value={line.product_id} onChange={e => updLine(idx, 'product_id', e.target.value)}>
                <option value="">— Επιλογή —</option>
                {products.filter(p => p.is_active).map(p => (
                  <option key={p.id} value={p.id}>
                    {p.name} — €{(p.price_cents / 100).toFixed(2)}{p.stock !== null ? ` (${p.stock} τεμ.)` : ''}
                  </option>
                ))}
              </select>
              <input type="number" min={1} className="form-input" style={{ width:70 }}
                value={line.qty} onChange={e => updLine(idx, 'qty', e.target.value)}/>
              {items.length > 1 && (
                <button className="btn btn-danger btn-sm" onClick={() => delLine(idx)}><X size={13}/></button>
              )}
            </div>
          ))}
          <button className="btn btn-secondary btn-sm" onClick={addLine} style={{ marginTop:4 }}>
            <Plus size={13}/> Προσθήκη
          </button>
        </div>
        {total > 0 && (
          <div style={{ background:'#f0fdf4', borderRadius:10, padding:'10px 16px', marginBottom:16,
            display:'flex', justifyContent:'space-between', alignItems:'center' }}>
            <span style={{ fontWeight:600, color:'#475569' }}>Σύνολο</span>
            <span style={{ fontSize:'1.25rem', fontWeight:800, color:'var(--hs-primary)' }}>€{(total / 100).toFixed(2)}</span>
          </div>
        )}
        <div className="form-grid-2">
          <div className="form-group">
            <label className="form-label">Πελάτης <span className="text-muted">(προαιρ.)</span></label>
            <input className="form-input" placeholder="Όνομα…" value={customer} onChange={e => setCustomer(e.target.value)}/>
          </div>
          <div className="form-group">
            <label className="form-label">Πληρωμή</label>
            <select className="form-select" value={method} onChange={e => setMethod(e.target.value)}>
              <option value="cash">Μετρητά</option>
              <option value="card">Κάρτα POS</option>
            </select>
          </div>
        </div>
        <div className="form-group">
          <label className="form-label">Σημειώσεις</label>
          <input className="form-input" value={notes} onChange={e => setNotes(e.target.value)}/>
        </div>
        <div className="modal-footer">
          <button className="btn btn-secondary" onClick={onClose}>Άκυρο</button>
          <button className="btn btn-primary" onClick={save} disabled={saving}>
            <Check size={15}/> {saving ? 'Καταχώριση…' : 'Ολοκλήρωση πώλησης'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Tab definitions ──────────────────────────────────────────
const TABS = [
  { id: 'products',        path: '/marketplace',               label: 'Προϊόντα',         icon: Package },
  { id: 'orders',          path: '/marketplace/orders',        label: 'Παραγγελίες',      icon: ClipboardList },
  { id: 'categories',      path: '/marketplace/categories',    label: 'Κατηγορίες',       icon: Tag },
  { id: 'shipping',        path: '/marketplace/shipping',      label: 'Αποστολή',         icon: Truck },
  { id: 'payment-methods', path: '/marketplace/payment-methods', label: 'Πληρωμές',       icon: CreditCard },
];

// ─── Main page ────────────────────────────────────────────────
export default function Marketplace() {
  const biz   = JSON.parse(localStorage.getItem('gym_admin_business') || '{}');
  const bizId = biz.id;
  const nav   = useNavigate();
  const loc   = useLocation();

  const activeTab = TABS.find(t =>
    t.path === '/marketplace' ? loc.pathname === '/marketplace' : loc.pathname.startsWith(t.path)
  )?.id || 'products';

  // products
  const [products, setProducts]       = useState([]);
  const [prodLoading, setProdLoading] = useState(true);
  const [modal, setModal]             = useState(null);
  const [inStoreModal, setInStore]    = useState(false);

  // orders
  const [orders, setOrders]           = useState([]);
  const [ordLoading, setOrdLoading]   = useState(true);

  // categories
  const [cats, setCats]               = useState([]);
  const [catLoading, setCatLoading]   = useState(false);
  const [catForm, setCatForm]         = useState({ name: '', sort_order: 0 });
  const [editCat, setEditCat]         = useState(null);

  // settings
  const [settings, setSettings] = useState({ shipping: {}, payment_methods: { cash: true, card: true } });
  const [settingsLoading, setSettingsLoading] = useState(false);
  const [settingsSaving,  setSettingsSaving]  = useState(false);

  useEffect(() => {
    api.get(`/marketplace/${bizId}/products`).then(r => setProducts(r.data.products || [])).finally(() => setProdLoading(false));
    api.get(`/marketplace/${bizId}/admin/orders`, { params: { limit: 200 } }).then(r => setOrders(r.data.orders || [])).finally(() => setOrdLoading(false));
  }, [bizId]);

  useEffect(() => {
    if (activeTab !== 'categories') return;
    setCatLoading(true);
    api.get(`/marketplace/${bizId}/admin/categories`).then(r => setCats(r.data.categories || [])).finally(() => setCatLoading(false));
  }, [activeTab, bizId]);

  useEffect(() => {
    if (activeTab !== 'shipping' && activeTab !== 'payment-methods') return;
    setSettingsLoading(true);
    api.get(`/marketplace/${bizId}/admin/settings`).then(r => setSettings(r.data)).finally(() => setSettingsLoading(false));
  }, [activeTab, bizId]);

  const handleSave = (prod) => {
    if (products.find(p => p.id === prod.id)) setProducts(products.map(p => p.id === prod.id ? { ...p, ...prod } : p));
    else setProducts(prev => [...prev, prod]);
  };

  const deleteProduct = async (id) => {
    if (!window.confirm('Απόκρυψη προϊόντος;')) return;
    await api.delete(`/marketplace/${bizId}/admin/products/${id}`);
    setProducts(products.filter(p => p.id !== id));
    toast.success('Αφαιρέθηκε');
  };

  const updateOrderStatus = async (orderId, status) => {
    try {
      await api.patch(`/marketplace/${bizId}/admin/orders/${orderId}/status`, { status });
      setOrders(orders.map(o => o.id === orderId ? { ...o, status } : o));
      toast.success('Status ενημερώθηκε');
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
  };

  const handleInStore = async (form) => {
    const r = await api.post(`/marketplace/${bizId}/admin/orders/in-store`, form);
    toast.success(`Πώληση €${(r.data.total_cents / 100).toFixed(2)} — ${form.payment_method === 'cash' ? 'Μετρητά' : 'Κάρτα'}`);
    api.get(`/marketplace/${bizId}/admin/orders`, { params: { limit: 200 } }).then(r2 => setOrders(r2.data.orders || []));
    api.get(`/marketplace/${bizId}/products`).then(r2 => setProducts(r2.data.products || []));
  };

  const createCat = async () => {
    if (!catForm.name.trim()) return;
    try {
      const r = await api.post(`/marketplace/${bizId}/admin/categories`, catForm);
      setCats([...cats, { id: r.data.id, name: r.data.name, sort_order: catForm.sort_order }]);
      setCatForm({ name: '', sort_order: 0 });
      toast.success('Κατηγορία δημιουργήθηκε');
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα'); }
  };

  const saveCat = async () => {
    if (!editCat) return;
    try {
      await api.put(`/marketplace/${bizId}/admin/categories/${editCat.id}`, editCat);
      setCats(cats.map(c => c.id === editCat.id ? editCat : c));
      setEditCat(null);
      toast.success('Αποθηκεύτηκε');
    } catch { toast.error('Σφάλμα'); }
  };

  const deleteCat = async (id) => {
    if (!window.confirm('Διαγραφή κατηγορίας;')) return;
    await api.delete(`/marketplace/${bizId}/admin/categories/${id}`);
    setCats(cats.filter(c => c.id !== id));
    toast.success('Διαγράφηκε');
  };

  const saveSettings = async (key, val) => {
    setSettings(s => ({ ...s, [key]: val }));
    setSettingsSaving(true);
    try {
      await api.put(`/marketplace/${bizId}/admin/settings`, { [key]: val });
      toast.success('Αποθηκεύτηκε');
    } catch { toast.error('Σφάλμα'); }
    finally { setSettingsSaving(false); }
  };

  const pendingOrders = orders.filter(o => o.status === 'pending' || o.status === 'paid').length;

  return (
    <Layout>
      <div className="page-header">
        <div style={{ display:'flex', alignItems:'center', gap:12 }}>
          <div style={{
            width:44, height:44, borderRadius:14,
            background:'linear-gradient(135deg,#fff7ed,#fed7aa)',
            display:'flex', alignItems:'center', justifyContent:'center', color:'#ea580c',
          }}>
            <ShoppingBag size={22}/>
          </div>
          <div>
            <h1 className="page-title">Marketplace</h1>
            <div className="text-muted" style={{ marginTop:2 }}>Προϊόντα, παραγγελίες και ρυθμίσεις</div>
          </div>
        </div>
        <div style={{ display:'flex', gap:8 }}>
          {activeTab === 'products' && (
            <button className="btn btn-primary" onClick={() => setModal('new')}>
              <Plus size={15}/> Νέο Προϊόν
            </button>
          )}
          <button className="btn btn-secondary" onClick={() => setInStore(true)}>
            <Store size={15}/> Πώληση καταστήματος
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ display:'flex', gap:2, borderBottom:'2px solid #e2e8f0', marginBottom:20, overflowX:'auto' }}>
        {TABS.map(t => (
          <button key={t.id} onClick={() => nav(t.path)} style={{
            display:'flex', alignItems:'center', gap:6, padding:'10px 16px',
            border:'none', background:'none', cursor:'pointer', whiteSpace:'nowrap',
            borderBottom:`2px solid ${activeTab === t.id ? 'var(--hs-primary)' : 'transparent'}`,
            marginBottom:-2,
            color: activeTab === t.id ? 'var(--hs-primary)' : '#64748b',
            fontWeight: activeTab === t.id ? 700 : 500, fontSize:'0.875rem',
          }}>
            <t.icon size={14}/> {t.label}
            {t.id === 'orders' && pendingOrders > 0 && (
              <span style={{ background:'#dc2626', color:'#fff', borderRadius:10, padding:'1px 6px', fontSize:'0.7rem', fontWeight:700 }}>
                {pendingOrders}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* ── PRODUCTS ── */}
      {activeTab === 'products' && (
        prodLoading ? <div className="loading">Φόρτωση…</div> : (
          <div className="card" style={{ padding:0, overflow:'hidden' }}>
            {products.length === 0 ? (
              <div className="bk-empty">
                <Package size={40} style={{ margin:'0 auto 12px', display:'block', color:'#94a3b8' }}/>
                <div style={{ fontWeight:700, color:'#1e293b' }}>Δεν υπάρχουν προϊόντα ακόμη</div>
                <div style={{ marginTop:12 }}>
                  <button className="btn btn-primary" onClick={() => setModal('new')}><Plus size={15}/> Νέο Προϊόν</button>
                </div>
              </div>
            ) : (
              <div style={{ overflowX:'auto' }}>
                <table>
                  <thead>
                    <tr>
                      <th style={{ width:60 }}></th>
                      <th>Προϊόν</th>
                      <th>SKU</th>
                      <th>Κατηγορία</th>
                      <th>Τιμή</th>
                      <th>Απόθεμα</th>
                      <th>Βάρος</th>
                      <th>Κατάσταση</th>
                      <th style={{ width:80 }}></th>
                    </tr>
                  </thead>
                  <tbody>
                    {products.map(p => (
                      <tr key={p.id}>
                        <td>
                          <div style={{ width:44, height:44, borderRadius:8, overflow:'hidden',
                            background:'#f1f5f9', display:'flex', alignItems:'center', justifyContent:'center' }}>
                            {imgSrc(p.image_url)
                              ? <img src={imgSrc(p.image_url)} alt="" style={{ width:'100%', height:'100%', objectFit:'cover' }}/>
                              : <Package size={20} style={{ color:'#cbd5e1' }}/>}
                          </div>
                        </td>
                        <td>
                          <strong>{p.name}</strong>
                          {p.description && <div className="text-muted" style={{ fontSize:'0.78rem' }}>{p.description}</div>}
                          {p.notes && <div className="text-muted" style={{ fontSize:'0.75rem', fontStyle:'italic' }}>{p.notes}</div>}
                        </td>
                        <td className="text-muted">{p.sku || '—'}</td>
                        <td className="text-muted">{p.category || '—'}</td>
                        <td><strong>€{(p.price_cents / 100).toFixed(2)}</strong></td>
                        <td>{p.stock === null ? <span className="text-muted">∞</span> : p.stock}</td>
                        <td className="text-muted">{p.weight_grams ? `${p.weight_grams}g` : '—'}</td>
                        <td>
                          <span className={`badge ${p.is_active ? 'badge-green' : 'badge-gray'}`}>
                            {p.is_active ? 'Ενεργό' : 'Ανενεργό'}
                          </span>
                        </td>
                        <td>
                          <div style={{ display:'flex', gap:4 }}>
                            <button className="btn btn-secondary btn-sm" onClick={() => setModal(p)}><Edit2 size={14}/></button>
                            <button className="btn btn-danger btn-sm" onClick={() => deleteProduct(p.id)}><Trash2 size={14}/></button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )
      )}

      {/* ── ORDERS ── */}
      {activeTab === 'orders' && (
        ordLoading ? <div className="loading">Φόρτωση…</div> : (
          <div className="card" style={{ padding:0, overflow:'hidden' }}>
            {orders.length === 0 ? (
              <div className="bk-empty">
                <ClipboardList size={40} style={{ margin:'0 auto 12px', display:'block', color:'#94a3b8' }}/>
                <div style={{ fontWeight:700, color:'#1e293b' }}>Δεν υπάρχουν παραγγελίες</div>
              </div>
            ) : (
              <div style={{ overflowX:'auto' }}>
                <table>
                  <thead>
                    <tr>
                      <th>Πελάτης / Πηγή</th>
                      <th>Προϊόντα</th>
                      <th>Σύνολο</th>
                      <th>Πληρωμή</th>
                      <th>Status</th>
                      <th>Ημερομηνία</th>
                      <th>Ενέργεια</th>
                    </tr>
                  </thead>
                  <tbody>
                    {orders.map(o => {
                      const st = ORDER_STATUS[o.status] || { label: o.status, cls: 'badge-gray' };
                      const items = typeof o.items === 'string' ? JSON.parse(o.items) : (o.items || []);
                      const isInStore = o.source === 'in_store';
                      return (
                        <tr key={o.id}>
                          <td>
                            {isInStore
                              ? <span className="badge badge-blue" style={{ display:'inline-flex', alignItems:'center', gap:4 }}><Store size={11}/> Κατάστημα</span>
                              : <strong>{o.user_name || '—'}</strong>}
                            {o.user_phone && !isInStore && <div className="text-muted">{o.user_phone}</div>}
                          </td>
                          <td className="text-muted" style={{ fontSize:'0.8rem', maxWidth:220 }}>
                            {items.map(i => `${i.name} ×${i.qty}`).join(', ')}
                          </td>
                          <td><strong>€{(o.total_cents / 100).toFixed(2)}</strong></td>
                          <td className="text-muted" style={{ fontSize:'0.8rem' }}>
                            {o.payment_method === 'cash' ? 'Μετρητά' : o.payment_method === 'card' ? 'Κάρτα' : o.provider || '—'}
                          </td>
                          <td><span className={`badge ${st.cls}`}>{st.label}</span></td>
                          <td className="text-muted">{new Date(o.created_at).toLocaleDateString('el-GR')}</td>
                          <td>
                            <div style={{ display:'flex', gap:4 }}>
                              {o.status === 'paid' && (
                                <button className="btn btn-primary btn-sm" onClick={() => updateOrderStatus(o.id, 'fulfilled')}>
                                  <Check size={13}/> Παράδοση
                                </button>
                              )}
                              {(o.status === 'pending' || o.status === 'paid') && (
                                <button className="btn btn-danger btn-sm" onClick={() => updateOrderStatus(o.id, 'cancelled')}>
                                  <X size={13}/> Ακύρωση
                                </button>
                              )}
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )
      )}

      {/* ── CATEGORIES ── */}
      {activeTab === 'categories' && (
        catLoading ? <div className="loading">Φόρτωση…</div> : (
          <div style={{ display:'flex', flexDirection:'column', gap:16 }}>
            <div className="card">
              <div style={{ fontWeight:700, marginBottom:12, color:'#1e293b' }}>Νέα κατηγορία</div>
              <div style={{ display:'flex', gap:8, alignItems:'flex-end' }}>
                <div className="form-group" style={{ flex:1, margin:0 }}>
                  <input className="form-input" placeholder="π.χ. Supplements, Merch, Equipment…"
                    value={catForm.name} onChange={e => setCatForm(f => ({ ...f, name: e.target.value }))}
                    onKeyDown={e => e.key === 'Enter' && createCat()}/>
                </div>
                <button className="btn btn-primary" onClick={createCat}><Plus size={15}/> Προσθήκη</button>
              </div>
            </div>
            {cats.length === 0 ? (
              <div className="bk-empty">
                <Tag size={36} style={{ margin:'0 auto 10px', display:'block', color:'#94a3b8' }}/>
                <div>Δεν υπάρχουν κατηγορίες ακόμη</div>
              </div>
            ) : (
              <div className="card" style={{ padding:0, overflow:'hidden' }}>
                <table>
                  <thead><tr><th>Όνομα</th><th>Σειρά</th><th style={{ width:100 }}></th></tr></thead>
                  <tbody>
                    {cats.map(c => (
                      <tr key={c.id}>
                        <td>
                          {editCat?.id === c.id
                            ? <input className="form-input" style={{ maxWidth:200 }} value={editCat.name}
                                onChange={e => setEditCat(ec => ({ ...ec, name: e.target.value }))}/>
                            : <strong>{c.name}</strong>}
                        </td>
                        <td>
                          {editCat?.id === c.id
                            ? <input type="number" className="form-input" style={{ width:70 }} value={editCat.sort_order}
                                onChange={e => setEditCat(ec => ({ ...ec, sort_order: Number(e.target.value) }))}/>
                            : c.sort_order}
                        </td>
                        <td>
                          <div style={{ display:'flex', gap:4 }}>
                            {editCat?.id === c.id ? (
                              <>
                                <button className="btn btn-primary btn-sm" onClick={saveCat}><Check size={13}/></button>
                                <button className="btn btn-secondary btn-sm" onClick={() => setEditCat(null)}><X size={13}/></button>
                              </>
                            ) : (
                              <>
                                <button className="btn btn-secondary btn-sm" onClick={() => setEditCat({ ...c })}><Edit2 size={13}/></button>
                                <button className="btn btn-danger btn-sm" onClick={() => deleteCat(c.id)}><Trash2 size={13}/></button>
                              </>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )
      )}

      {/* ── SHIPPING ── */}
      {activeTab === 'shipping' && (
        settingsLoading ? <div className="loading">Φόρτωση…</div> : (
          <div className="card" style={{ maxWidth:520 }}>
            <div style={{ fontWeight:700, fontSize:'1rem', marginBottom:20, color:'#1e293b', display:'flex', alignItems:'center', gap:8 }}>
              <Truck size={18}/> Ρυθμίσεις Αποστολής
            </div>
            {[
              { key:'enabled',              label:'Ενεργοποίηση αποστολής',       type:'toggle' },
              { key:'flat_rate_cents',      label:'Κόστος αποστολής (€)',          type:'money' },
              { key:'free_threshold_cents', label:'Δωρεάν αποστολή από (€)',       type:'money' },
              { key:'estimated_days',       label:'Εκτιμώμενες μέρες παράδοσης', type:'text', placeholder:'π.χ. 2-3' },
              { key:'notes',                label:'Σημειώσεις αποστολής',          type:'text', placeholder:'Επιπλέον πληροφορίες…' },
            ].map(field => {
              const val = settings.shipping?.[field.key];
              const onChange = (v) => setSettings(s => ({ ...s, shipping: { ...s.shipping, [field.key]: v } }));
              return (
                <div key={field.key} className="form-group">
                  <label className="form-label">{field.label}</label>
                  {field.type === 'toggle' ? (
                    <label style={{ display:'flex', alignItems:'center', gap:10, cursor:'pointer' }}>
                      <span className="toggle">
                        <input type="checkbox" checked={!!val} onChange={e => onChange(e.target.checked)}/>
                        <span className="toggle-slider"/>
                      </span>
                      <span style={{ fontSize:'0.875rem', color:'#475569' }}>{val ? 'Ενεργή' : 'Ανενεργή'}</span>
                    </label>
                  ) : field.type === 'money' ? (
                    <input type="number" min={0} step={0.01} className="form-input" style={{ maxWidth:160 }}
                      value={val != null ? (val / 100).toFixed(2) : ''}
                      onChange={e => onChange(Math.round(parseFloat(e.target.value || 0) * 100))}/>
                  ) : (
                    <input className="form-input" style={{ maxWidth:300 }} placeholder={field.placeholder || ''}
                      value={val || ''} onChange={e => onChange(e.target.value)}/>
                  )}
                </div>
              );
            })}
            <div style={{ marginTop:8 }}>
              <button className="btn btn-primary" onClick={() => saveSettings('shipping', settings.shipping)} disabled={settingsSaving}>
                <Check size={15}/> {settingsSaving ? 'Αποθήκευση…' : 'Αποθήκευση ρυθμίσεων'}
              </button>
            </div>
          </div>
        )
      )}

      {/* ── PAYMENT METHODS ── */}
      {activeTab === 'payment-methods' && (
        settingsLoading ? <div className="loading">Φόρτωση…</div> : (
          <div className="card" style={{ maxWidth:480 }}>
            <div style={{ fontWeight:700, fontSize:'1rem', marginBottom:20, color:'#1e293b', display:'flex', alignItems:'center', gap:8 }}>
              <CreditCard size={18}/> Τρόποι Πληρωμής
            </div>
            {[
              { key:'cash',          label:'Μετρητά',            desc:'Πληρωμή με μετρητά στο κατάστημα' },
              { key:'card',          label:'Κάρτα POS',          desc:'Πληρωμή με κάρτα μέσω τερματικού POS' },
              { key:'stripe',        label:'Stripe (online)',     desc:'Online πληρωμή μέσω Stripe' },
              { key:'bank_transfer', label:'Τραπεζική μεταφορά', desc:'Κατάθεση σε τραπεζικό λογαριασμό' },
            ].map(m => (
              <div key={m.key} style={{ padding:'12px 0', borderBottom:'1px solid #f1f5f9', display:'flex', justifyContent:'space-between', alignItems:'center' }}>
                <div>
                  <div style={{ fontWeight:600, color:'#1e293b' }}>{m.label}</div>
                  <div className="text-muted" style={{ fontSize:'0.8rem', marginTop:2 }}>{m.desc}</div>
                </div>
                <label style={{ cursor:'pointer' }}>
                  <span className="toggle">
                    <input type="checkbox"
                      checked={!!settings.payment_methods?.[m.key]}
                      onChange={e => setSettings(s => ({
                        ...s, payment_methods: { ...s.payment_methods, [m.key]: e.target.checked }
                      }))}/>
                    <span className="toggle-slider"/>
                  </span>
                </label>
              </div>
            ))}
            <div style={{ marginTop:16 }}>
              <button className="btn btn-primary" onClick={() => saveSettings('payment_methods', settings.payment_methods)} disabled={settingsSaving}>
                <Check size={15}/> {settingsSaving ? 'Αποθήκευση…' : 'Αποθήκευση ρυθμίσεων'}
              </button>
            </div>
          </div>
        )
      )}

      {modal && (
        <ProductModal
          product={modal === 'new' ? null : modal}
          categories={cats}
          bizId={bizId}
          onClose={() => setModal(null)}
          onSave={handleSave}
        />
      )}
      {inStoreModal && (
        <InStoreModal
          products={products}
          onClose={() => setInStore(false)}
          onSave={handleInStore}
        />
      )}
    </Layout>
  );
}
