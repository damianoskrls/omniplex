import { useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Plus, Trash2, Edit2, Check, X, GripVertical, ImagePlus } from 'lucide-react';
import { mediaUrl } from '../utils/media';

export default function Rooms() {
  const [rooms, setRooms] = useState([]);
  const [locations, setLocations] = useState([]);
  const [activeLocationId, setActiveLocationId] = useState('');
  const [form, setForm] = useState({ name: '', short_info: '' });
  const [editingId, setEditingId] = useState(null);
  const [editForm, setEditForm] = useState({});
  const [saving, setSaving] = useState(false);
  const [uploadingId, setUploadingId] = useState(null);
  const fileRefs = useRef({});

  const load = async () => {
    const locRes = await api.get('/client-admin/locations');
    const locs = (locRes.data || []).filter((l) => l.is_active);
    setLocations(locs);
    const locId = activeLocationId || locs[0]?.id || '';
    if (!activeLocationId && locId) setActiveLocationId(locId);
    const params = locId ? { location_id: locId } : {};
    const res = await api.get('/client-admin/rooms', { params });
    setRooms(res.data);
  };

  useEffect(() => { load().catch(() => toast.error('Σφάλμα φόρτωσης')); }, [activeLocationId]);

  const addRoom = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) return toast.error('Βάλε όνομα αίθουσας');
    setSaving(true);
    try {
      await api.post('/client-admin/rooms', {
        name: form.name.trim(),
        short_info: form.short_info.trim() || null,
        sort_order: rooms.length,
        location_id: activeLocationId || undefined,
      });
      toast.success('Αίθουσα προστέθηκε');
      setForm({ name: '', short_info: '' });
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  const startEdit = (room) => {
    setEditingId(room.id);
    setEditForm({
      name: room.name,
      short_info: room.short_info || room.description || '',
    });
  };

  const saveEdit = async (id) => {
    if (!editForm.name.trim()) return toast.error('Το όνομα είναι υποχρεωτικό');
    await api.patch(`/client-admin/rooms/${id}`, {
      name: editForm.name.trim(),
      short_info: editForm.short_info.trim() || null,
      description: editForm.short_info.trim() || null,
    });
    toast.success('Αποθηκεύτηκε');
    setEditingId(null);
    load();
  };

  const uploadPhoto = async (roomId, file) => {
    if (!file) return;
    setUploadingId(roomId);
    try {
      const formData = new FormData();
      formData.append('image', file);
      await api.post(`/client-admin/rooms/${roomId}/image`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      toast.success('Η φωτογραφία ανέβηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα ανεβάσματος');
    } finally {
      setUploadingId(null);
    }
  };

  const deleteRoom = async (id, name) => {
    if (!window.confirm(`Διαγραφή αίθουσας "${name}";`)) return;
    await api.delete(`/client-admin/rooms/${id}`);
    toast.success('Διαγράφηκε');
    load();
  };

  return (
    <Layout title="Αίθουσες">
      <div className="page-header">
        <h1 className="page-title">Αίθουσες γυμναστηρίου</h1>
        <p className="text-muted">Ορίστε αίθουσες ανά τοποθεσία με φωτογραφία και πληροφορίες για τους πελάτες.</p>
        {locations.length > 1 && (
          <div style={{ marginTop: 12 }}>
            <select className="form-select" style={{ width: 240 }} value={activeLocationId} onChange={(e) => setActiveLocationId(e.target.value)}>
              {locations.map((loc) => <option key={loc.id} value={loc.id}>{loc.name}</option>)}
            </select>
          </div>
        )}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24, alignItems: 'start' }}>
        <div className="card">
          <div className="modal-title" style={{ marginBottom: 16 }}>Νέα αίθουσα</div>
          <form onSubmit={addRoom}>
            <div className="form-group">
              <label className="form-label">Όνομα *</label>
              <input
                className="form-input"
                placeholder="π.χ. Αίθουσα 1 — 1ος Όροφος"
                value={form.name}
                onChange={e => setForm({ ...form, name: e.target.value })}
                autoFocus
              />
            </div>
            <div className="form-group">
              <label className="form-label">Σύντομες πληροφορίες (προαιρετικό)</label>
              <textarea
                className="form-input"
                rows={3}
                placeholder="π.χ. Ομαδικά μαθήματα, χωρητικότητα 15, πρόσβαση από ασανσέρ"
                value={form.short_info}
                onChange={e => setForm({ ...form, short_info: e.target.value })}
              />
            </div>
            <button type="submit" className="btn btn-primary" disabled={saving}>
              <Plus size={14} /> Προσθήκη
            </button>
          </form>
        </div>

        <div className="card">
          <div className="modal-title" style={{ marginBottom: 16 }}>
            Αίθουσες ({rooms.length})
          </div>
          {rooms.length === 0 ? (
            <div className="text-muted">Δεν έχεις ορίσει αίθουσες ακόμα.</div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {rooms.map(room => {
                const photo = mediaUrl(room.photo_url);
                return (
                  <div
                    key={room.id}
                    style={{
                      display: 'flex',
                      alignItems: 'flex-start',
                      gap: 10,
                      padding: '10px 12px',
                      background: '#f8fafc',
                      borderRadius: 10,
                      border: '1px solid #e2e8f0',
                    }}
                  >
                    <GripVertical size={16} style={{ color: '#cbd5e1', flexShrink: 0, marginTop: 4 }} />
                    <div style={{ width: 72, flexShrink: 0 }}>
                      {photo ? (
                        <img src={photo} alt={room.name} style={{ width: 72, height: 54, objectFit: 'cover', borderRadius: 8 }} />
                      ) : (
                        <div style={{
                          width: 72, height: 54, borderRadius: 8, background: '#e2e8f0',
                          display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: 11,
                        }}>
                          Χωρίς φωτό
                        </div>
                      )}
                      <input
                        ref={(el) => { fileRefs.current[room.id] = el; }}
                        type="file"
                        accept="image/*"
                        style={{ display: 'none' }}
                        onChange={(e) => uploadPhoto(room.id, e.target.files?.[0])}
                      />
                      <button
                        type="button"
                        className="btn btn-secondary btn-sm"
                        style={{ width: '100%', marginTop: 6, fontSize: '0.72rem' }}
                        disabled={uploadingId === room.id}
                        onClick={() => fileRefs.current[room.id]?.click()}
                      >
                        <ImagePlus size={12} /> Φωτό
                      </button>
                    </div>

                    {editingId === room.id ? (
                      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
                        <input
                          className="form-input"
                          value={editForm.name}
                          onChange={e => setEditForm({ ...editForm, name: e.target.value })}
                          autoFocus
                        />
                        <textarea
                          className="form-input"
                          rows={2}
                          value={editForm.short_info}
                          onChange={e => setEditForm({ ...editForm, short_info: e.target.value })}
                          placeholder="Σύντομες πληροφορίες"
                        />
                        <div style={{ display: 'flex', gap: 8 }}>
                          <button onClick={() => saveEdit(room.id)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#22c55e' }}>
                            <Check size={16} />
                          </button>
                          <button onClick={() => setEditingId(null)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#94a3b8' }}>
                            <X size={16} />
                          </button>
                        </div>
                      </div>
                    ) : (
                      <>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontWeight: 600, fontSize: '0.9rem' }}>{room.name}</div>
                          {(room.short_info || room.description) && (
                            <div style={{ fontSize: '0.78rem', color: '#64748b', marginTop: 4, whiteSpace: 'pre-wrap' }}>
                              {room.short_info || room.description}
                            </div>
                          )}
                        </div>
                        <button onClick={() => startEdit(room)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#64748b' }}>
                          <Edit2 size={14} />
                        </button>
                        <button onClick={() => deleteRoom(room.id, room.name)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#ef4444' }}>
                          <Trash2 size={14} />
                        </button>
                      </>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
}
