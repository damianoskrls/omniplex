import { useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Link } from 'react-router-dom';
import LocationCheckboxes from '../components/LocationCheckboxes';
import { Plus, Trash2, Pencil, CalendarClock, Upload, X, Check } from 'lucide-react';
import { mediaUrl } from '../utils/media';

const EMPTY = { name: '', description: '', category: '', duration_mins: 60, hide_staff_selection: false, slot_label_mode: 'time_only', drop_in_price_cents: '', requires_attendance_confirmation: true, requires_qr_scan: true };

function ImageUploadBox({ label, accept, currentUrl, onUpload, onRemove, hint }) {
  const inputRef = useRef();
  const [uploading, setUploading] = useState(false);
  const [preview, setPreview] = useState(null);

  const handleFile = async (file) => {
    if (!file) return;
    setPreview(URL.createObjectURL(file));
    setUploading(true);
    try {
      await onUpload(file);
      toast.success(`${label} ανέβηκε`);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
      setPreview(null);
    } finally {
      setUploading(false);
    }
  };

  const displayed = preview || (currentUrl ? mediaUrl(currentUrl) : null);

  return (
    <div style={{ flex: 1 }}>
      <div style={{ fontSize: '0.82rem', fontWeight: 600, color: '#374151', marginBottom: 8 }}>{label}</div>
      {hint && <div style={{ fontSize: '0.75rem', color: '#94a3b8', marginBottom: 8 }}>{hint}</div>}

      <div
        onClick={() => inputRef.current?.click()}
        onDragOver={e => e.preventDefault()}
        onDrop={e => { e.preventDefault(); handleFile(e.dataTransfer.files[0]); }}
        style={{
          border: '2px dashed #cbd5e1',
          borderRadius: 12,
          padding: 12,
          cursor: 'pointer',
          background: '#f8fafc',
          textAlign: 'center',
          minHeight: 100,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 6,
          position: 'relative',
          transition: 'border-color 0.15s',
        }}
      >
        {displayed ? (
          <>
            <img
              src={displayed}
              alt=""
              style={{ maxHeight: 80, maxWidth: '100%', objectFit: 'contain', borderRadius: 6 }}
            />
            <div style={{ fontSize: '0.75rem', color: '#64748b' }}>Κλικ για αλλαγή</div>
          </>
        ) : (
          <>
            <Upload size={24} style={{ color: '#94a3b8' }} />
            <div style={{ fontSize: '0.8rem', color: '#64748b' }}>
              {uploading ? 'Ανέβασμα...' : 'Κλικ ή σύρε εδώ'}
            </div>
          </>
        )}
        {uploading && (
          <div style={{ position: 'absolute', inset: 0, background: 'rgba(255,255,255,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 12 }}>
            <div style={{ fontSize: '0.85rem', color: '#76C043' }}>Ανέβασμα...</div>
          </div>
        )}
      </div>

      <input ref={inputRef} type="file" accept={accept} style={{ display: 'none' }} onChange={e => handleFile(e.target.files[0])} />

      {displayed && onRemove && (
        <button
          type="button"
          onClick={onRemove}
          style={{ marginTop: 6, fontSize: '0.75rem', color: '#ef4444', border: 'none', background: 'none', cursor: 'pointer', padding: 0 }}
        >
          <X size={12} style={{ marginRight: 3 }} />Αφαίρεση
        </button>
      )}
    </div>
  );
}

export default function Services() {
  const [services, setServices] = useState([]);
  const [plans, setPlans] = useState([]);
  const [rooms, setRooms] = useState([]);
  const [icons, setIcons] = useState([]);
  const [modal, setModal] = useState(null);
  const [form, setForm] = useState(EMPTY);
  const [planIds, setPlanIds] = useState([]);
  const [roomIds, setRoomIds] = useState([]);
  const [locationIds, setLocationIds] = useState([]);
  const [saving, setSaving] = useState(false);
  const [editingService, setEditingService] = useState(null);

  const load = async () => {
    const [svc, pl, rm, ic] = await Promise.all([
      api.get('/client-admin/services'),
      api.get('/client-admin/plans'),
      api.get('/client-admin/rooms'),
      api.get('/client-admin/icons'),
    ]);
    setServices(svc.data);
    setPlans(pl.data);
    setRooms(rm.data);
    setIcons(ic.data);
  };
  useEffect(() => { load().catch(() => {}); }, []);

  const openCreate = () => {
    setForm(EMPTY);
    setPlanIds([]);
    setRoomIds([]);
    setLocationIds([]);
    setEditingService(null);
    setModal('create');
  };

  const openEdit = async (s) => {
    setForm({
      name: s.name, description: s.description || '', category: s.category || '',
      duration_mins: s.duration_mins || 60,
      hide_staff_selection: !!s.hide_staff_selection,
      slot_label_mode: s.slot_label_mode || 'time_only',
      drop_in_price_cents: s.drop_in_price_cents != null ? String(Math.round(s.drop_in_price_cents / 100)) : '',
      requires_attendance_confirmation: s.requires_attendance_confirmation !== false,
      requires_qr_scan: s.requires_qr_scan !== false,
      id: s.id,
    });
    setEditingService(s);
    const [planRes, roomRes, locRes] = await Promise.all([
      api.get(`/client-admin/services/${s.id}/plan-ids`),
      api.get(`/client-admin/services/${s.id}/rooms`),
      api.get(`/client-admin/services/${s.id}/locations`),
    ]);
    setPlanIds(planRes.data);
    setRoomIds(roomRes.data.map(r => r.id));
    setLocationIds(locRes.data || []);
    setModal('edit');
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    const dropInEuros = parseFloat(form.drop_in_price_cents);
    const payload = {
      name: form.name,
      description: form.description || null,
      category: form.category || null,
      duration_mins: Number(form.duration_mins) || 60,
      hide_staff_selection: form.hide_staff_selection,
      slot_label_mode: form.slot_label_mode,
      location_ids: locationIds,
      drop_in_price_cents: form.drop_in_price_cents === '' ? null : Math.round(dropInEuros * 100),
      requires_attendance_confirmation: form.requires_attendance_confirmation,
      requires_qr_scan: form.requires_qr_scan,
    };
    try {
      let serviceId = form.id;
      if (modal === 'create') {
        const r = await api.post('/client-admin/services', payload);
        serviceId = r.data.id;
        toast.success('Υπηρεσία δημιουργήθηκε');
      } else {
        await api.patch(`/client-admin/services/${serviceId}`, payload);
        toast.success('Ενημερώθηκε');
      }
      await Promise.all([
        api.put(`/client-admin/services/${serviceId}/plans`, { plan_ids: planIds }),
        api.put(`/client-admin/services/${serviceId}/rooms`, { room_ids: roomIds }),
        api.put(`/client-admin/services/${serviceId}/locations`, { location_ids: locationIds }),
      ]);
      setModal(null);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  const uploadImage = async (file, serviceId) => {
    const fd = new FormData();
    fd.append('image', file);
    const res = await api.post(`/client-admin/services/${serviceId}/image`, fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    setEditingService(prev => ({ ...prev, image_url: res.data.image_url }));
    load();
  };

  const uploadSvg = async (file, serviceId) => {
    const fd = new FormData();
    fd.append('svg', file);
    const res = await api.post(`/client-admin/services/${serviceId}/svg`, fd, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    setEditingService(prev => ({ ...prev, icon_svg_url: res.data.icon_svg_url }));
    load();
  };

  const removeImage = async (serviceId) => {
    await api.patch(`/client-admin/services/${serviceId}`, { image_url: null });
    setEditingService(prev => ({ ...prev, image_url: null }));
    load();
  };

  const removeSvg = async (serviceId) => {
    await api.delete(`/client-admin/services/${serviceId}/svg`);
    setEditingService(prev => ({ ...prev, icon_svg_url: null }));
    load();
  };

  const toggleActive = async (s) => {
    await api.patch(`/client-admin/services/${s.id}`, { is_active: s.is_active ? 0 : 1 });
    load();
  };

  const remove = async (id) => {
    if (!window.confirm('Διαγραφή;')) return;
    await api.delete(`/client-admin/services/${id}`);
    load();
  };

  const togglePlan = (pid) => {
    setPlanIds(prev => prev.includes(pid) ? prev.filter(x => x !== pid) : [...prev, pid]);
  };

  return (
    <Layout title="Υπηρεσίες">
      <div className="page-header">
        <h1 className="page-title">Υπηρεσίες ({services.length})</h1>
        <button className="btn btn-primary" onClick={openCreate}><Plus size={16} /> Νέα υπηρεσία</button>
      </div>

      <div className="card">
        <table>
          <thead>
            <tr><th></th><th>Όνομα</th><th>Γυμναστήρια</th><th>Περιγραφή</th><th>Κατάσταση</th><th></th></tr>
          </thead>
          <tbody>
            {services.map(s => (
              <tr key={s.id} style={{ verticalAlign: 'middle' }}>
                <td style={{ width: 48, verticalAlign: 'middle' }}>
                  {s.icon_svg_url ? (
                    <img src={mediaUrl(s.icon_svg_url)} alt="" style={{ width: 36, height: 36, display: 'block' }} />
                  ) : s.image_url ? (
                    <img src={mediaUrl(s.image_url)} alt="" style={{ width: 36, height: 36, objectFit: 'cover', borderRadius: 6, display: 'block' }} />
                  ) : (
                    <div style={{ width: 36, height: 36, borderRadius: 6, background: '#f1f5f9', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#cbd5e1', fontSize: 18 }}>
                      🏋️
                    </div>
                  )}
                </td>
                <td style={{ fontWeight: 600, verticalAlign: 'middle' }}>
                  <div>{s.name}</div>
                  <div className="text-muted" style={{ fontWeight: 400 }}>{s.category}</div>
                  <span className={`badge ${s.hide_staff_selection ? 'badge-blue' : 'badge-gray'}`} style={{ marginTop: 4 }}>
                    {s.hide_staff_selection ? 'Αυτόματη ανάθεση' : 'Επιλογή γυμναστή'}
                  </span>
                </td>
                <td style={{ fontSize: '0.85rem', maxWidth: 140, verticalAlign: 'middle' }}>
                  {s.location_count > 0 ? (s.location_names || '—') : <span className="text-muted">Όλα</span>}
                </td>
                <td style={{ maxWidth: 200, verticalAlign: 'middle' }}>{s.description || '—'}</td>
                <td style={{ verticalAlign: 'middle' }}>
                  <button className={`badge ${s.is_active ? 'badge-green' : 'badge-red'}`} onClick={() => toggleActive(s)}>
                    {s.is_active ? 'Ενεργή' : 'Ανενεργή'}
                  </button>
                </td>
                <td style={{ verticalAlign: 'middle', whiteSpace: 'nowrap' }}>
                  <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
                    <Link to={`/services/${s.id}/schedule`} className="btn btn-secondary btn-sm" title="Πρόγραμμα ωρών & χωρητικότητα">
                      <CalendarClock size={14} /> Πρόγραμμα
                    </Link>
                    <button className="btn btn-secondary btn-sm" onClick={() => openEdit(s)}><Pencil size={14} /></button>
                    <button className="btn btn-danger btn-sm" onClick={() => remove(s.id)}><Trash2 size={14} /></button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {modal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setModal(null)}>
          <div className="modal" style={{ maxWidth: 560 }}>
            <div className="modal-title">{modal === 'create' ? 'Νέα υπηρεσία' : 'Επεξεργασία υπηρεσίας'}</div>
            <form onSubmit={handleSave}>
              <div className="form-group">
                <label className="form-label">Όνομα *</label>
                <input className="form-input" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} required autoFocus />
              </div>
              <div className="form-group">
                <label className="form-label">Περιγραφή</label>
                <textarea className="form-input" rows={2} value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} />
              </div>
              <div className="form-group">
                <label className="form-label">Κατηγορία</label>
                <input className="form-input" value={form.category} onChange={e => setForm({ ...form, category: e.target.value })} placeholder="π.χ. Classes, Training" />
              </div>
              <div className="form-group">
                <label className="form-label">Διάρκεια (λεπτά) *</label>
                <input
                  className="form-input"
                  type="number"
                  min={5}
                  step={5}
                  value={form.duration_mins}
                  onChange={e => setForm({ ...form, duration_mins: e.target.value })}
                  required
                />
              </div>

              <LocationCheckboxes
                value={locationIds}
                onChange={setLocationIds}
                label="Διαθέσιμη σε γυμναστήρια"
              />

              {/* Images + SVG icon — only when editing */}
              {modal === 'edit' && editingService && (
                <>
                  <div className="form-group">
                    <label className="form-label">Εικόνα υπηρεσίας</label>
                    <div style={{ display: 'flex', gap: 12 }}>
                      <ImageUploadBox
                        label="Φωτογραφία (JPG/PNG/WebP)"
                        accept="image/jpeg,image/png,image/webp,image/gif"
                        currentUrl={editingService.image_url}
                        onUpload={file => uploadImage(file, editingService.id)}
                        onRemove={() => removeImage(editingService.id)}
                        hint="Banner ή εξώφυλλο"
                      />
                      <ImageUploadBox
                        label="Custom Animated SVG"
                        accept=".svg,image/svg+xml"
                        currentUrl={editingService.icon_svg_url}
                        onUpload={file => uploadSvg(file, editingService.id)}
                        onRemove={() => removeSvg(editingService.id)}
                        hint="Upload δικό σου animated SVG"
                      />
                    </div>
                  </div>

                  {/* Built-in animated icons */}
                  <div className="form-group">
                    <label className="form-label">Ή επίλεξε built-in animated icon</label>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
                      {/* Clear selection */}
                      <button
                        type="button"
                        onClick={async () => { await removeSvg(editingService.id); }}
                        style={{
                          width: 64, height: 64, borderRadius: 12, border: '2px solid #e2e8f0',
                          background: !editingService.icon_svg_url ? '#f1f5f9' : '#fff',
                          cursor: 'pointer', fontSize: '0.7rem', color: '#94a3b8', display: 'flex',
                          flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2,
                        }}
                      >
                        <X size={18} />Καμία
                      </button>
                      {icons.map(ic => {
                        const isSelected = editingService.icon_svg_url === ic.url;
                        return (
                          <button
                            key={ic.key}
                            type="button"
                            title={ic.label}
                            onClick={async () => {
                              await api.patch(`/client-admin/services/${editingService.id}`, { icon_svg_url: ic.url });
                              setEditingService(prev => ({ ...prev, icon_svg_url: ic.url }));
                              load();
                            }}
                            style={{
                              width: 64, height: 64, borderRadius: 12, padding: 6,
                              border: `2px solid ${isSelected ? '#76C043' : '#e2e8f0'}`,
                              background: isSelected ? '#f0fdf4' : '#fff',
                              cursor: 'pointer', position: 'relative',
                            }}
                          >
                            <img src={mediaUrl(ic.url)} alt={ic.label} style={{ width: '100%', height: '100%', objectFit: 'contain' }} />
                            {isSelected && (
                              <div style={{ position: 'absolute', top: 2, right: 2, background: '#76C043', borderRadius: '50%', width: 16, height: 16, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                <Check size={10} color="#fff" />
                              </div>
                            )}
                            <div style={{ fontSize: '0.6rem', color: '#64748b', marginTop: 2 }}>{ic.label}</div>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                </>
              )}
              {modal === 'create' && (
                <div className="text-muted" style={{ fontSize: '0.8rem', marginBottom: 12 }}>
                  Μπορείς να προσθέσεις εικόνες και icon μετά τη δημιουργία.
                </div>
              )}

              <div className="form-group">
                <label className="form-label">Εμφάνιση ωρών στο app</label>
                <select className="form-input" value={form.slot_label_mode} onChange={e => setForm({ ...form, slot_label_mode: e.target.value })}>
                  <option value="time_only">Μόνο ώρα</option>
                  <option value="class">Όνομα μαθήματος</option>
                  <option value="room">Αίθουσα</option>
                </select>
              </div>
              <div className="form-group">
                <label style={{ display: 'flex', alignItems: 'flex-start', gap: 10, cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={!!form.hide_staff_selection}
                    onChange={e => setForm({ ...form, hide_staff_selection: e.target.checked })}
                    style={{ marginTop: 3 }}
                  />
                  <span>
                    <strong>Αυτόματη ανάθεση γυμναστή</strong>
                    <div className="text-muted" style={{ marginTop: 4, lineHeight: 1.4 }}>
                      Ο πελάτης δεν επιλέγει γυμναστή — το σύστημα αναθέτει αυτόματα.
                    </div>
                  </span>
                </label>
              </div>

              <div className="form-group">
                <label className="form-label">Τιμή drop-in (€)</label>
                <input
                  className="form-input"
                  type="number"
                  min={0}
                  step={0.5}
                  placeholder="π.χ. 12"
                  value={form.drop_in_price_cents}
                  onChange={e => setForm({ ...form, drop_in_price_cents: e.target.value })}
                />
                <div className="text-muted" style={{ marginTop: 4, fontSize: '0.8rem' }}>
                  Τιμή για μεμονωμένη συνεδρία χωρίς πακέτο. Αφήστε κενό αν δεν επιτρέπεται drop-in.
                </div>
              </div>

              <div className="form-group">
                <label style={{ display: 'flex', alignItems: 'flex-start', gap: 10, cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={!!form.requires_attendance_confirmation}
                    onChange={e => setForm({ ...form, requires_attendance_confirmation: e.target.checked })}
                    style={{ marginTop: 3 }}
                  />
                  <span>
                    <strong>Απαιτεί επιβεβαίωση παρουσίας</strong>
                    <div className="text-muted" style={{ marginTop: 4, lineHeight: 1.4 }}>
                      Μετά τη λήξη, απαιτείται check-in για να επιβεβαιωθεί η παρουσία του πελάτη.
                    </div>
                  </span>
                </label>
              </div>

              <div className="form-group">
                <label style={{ display: 'flex', alignItems: 'flex-start', gap: 10, cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={!!form.requires_qr_scan}
                    onChange={e => setForm({ ...form, requires_qr_scan: e.target.checked })}
                    style={{ marginTop: 3 }}
                  />
                  <span>
                    <strong>Απαιτεί QR scan</strong>
                    <div className="text-muted" style={{ marginTop: 4, lineHeight: 1.4 }}>
                      Ο πελάτης πρέπει να σκανάρει QR για να αφαιρεθεί συνεδρία. Απενεργοποιήστε για απεριόριστα πακέτα.
                    </div>
                  </span>
                </label>
              </div>
              {rooms.length > 0 && (
                <div className="form-group">
                  <label className="form-label">
                    Αίθουσες που γίνεται η υπηρεσία
                    <span style={{ fontWeight: 400, color: '#94a3b8', marginLeft: 6, fontSize: '0.8rem' }}>
                      {roomIds.length === 0 ? '(οποιαδήποτε)' : `${roomIds.length} επιλεγμένες`}
                    </span>
                  </label>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                    <button
                      type="button"
                      onClick={() => setRoomIds([])}
                      style={{ padding: '5px 14px', borderRadius: 20, border: `1.5px solid ${roomIds.length === 0 ? '#64748b' : '#e2e8f0'}`, background: roomIds.length === 0 ? '#f1f5f9' : '#fff', color: roomIds.length === 0 ? '#475569' : '#64748b', fontWeight: roomIds.length === 0 ? 700 : 400, fontSize: '0.85rem', cursor: 'pointer' }}
                    >
                      Οποιαδήποτε
                    </button>
                    {rooms.map(r => {
                      const checked = roomIds.includes(r.id);
                      return (
                        <button
                          key={r.id}
                          type="button"
                          onClick={() => setRoomIds(prev => checked ? prev.filter(x => x !== r.id) : [...prev, r.id])}
                          style={{ padding: '5px 14px', borderRadius: 20, border: `1.5px solid ${checked ? '#76C043' : '#e2e8f0'}`, background: checked ? '#f0fdf4' : '#fff', color: checked ? '#76C043' : '#64748b', fontWeight: checked ? 700 : 400, fontSize: '0.85rem', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 5 }}
                        >
                          {checked && <Check size={12} />}{r.name}
                        </button>
                      );
                    })}
                  </div>
                </div>
              )}

              {plans.length > 0 && (
                <div className="form-group">
                  <label className="form-label">Συνδεδεμένα πακέτα (τιμολόγηση)</label>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                    {plans.map(p => (
                      <label key={p.id} style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '4px 10px', border: '1px solid #e2e8f0', borderRadius: 8, background: planIds.includes(p.id) ? '#f0fdf4' : '#fff', cursor: 'pointer' }}>
                        <input type="checkbox" checked={planIds.includes(p.id)} onChange={() => togglePlan(p.id)} />
                        {p.name} ({p.sessions ?? '∞'} συν./{p.billing_period})
                      </label>
                    ))}
                  </div>
                </div>
              )}
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setModal(null)}>Ακύρωση</button>
                <button type="submit" className="btn btn-primary" disabled={saving}>Αποθήκευση</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </Layout>
  );
}
