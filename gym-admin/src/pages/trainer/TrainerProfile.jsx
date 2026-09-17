import { useEffect, useState } from 'react';
import Layout from '../../components/Layout';
import api from '../../api/client';
import toast from 'react-hot-toast';
import { Save, Upload } from 'lucide-react';
import { API_BASE } from '../../utils/media';


export default function TrainerProfile() {
  const [profile, setProfile] = useState(null);
  const [bio, setBio] = useState('');
  const [colorHex, setColorHex] = useState('#607D8B');
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [loading, setLoading] = useState(true);
  const [savingProfile, setSavingProfile] = useState(false);
  const [savingPassword, setSavingPassword] = useState(false);
  const [uploading, setUploading] = useState(false);

  const load = async () => {
    const r = await api.get('/client-admin/trainer/profile');
    setProfile(r.data);
    setBio(r.data.bio || '');
    setColorHex(r.data.color_hex || '#607D8B');
  };

  useEffect(() => {
    load().catch(() => toast.error('Σφάλμα φόρτωσης')).finally(() => setLoading(false));
  }, []);

  const saveProfile = async () => {
    setSavingProfile(true);
    try {
      const r = await api.patch('/client-admin/trainer/profile', { bio, color_hex: colorHex });
      setProfile(r.data);
      toast.success('Το προφίλ αποθηκεύτηκε');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSavingProfile(false);
    }
  };

  const savePassword = async () => {
    if (!currentPassword || !newPassword) {
      toast.error('Συμπλήρωσε τρέχον και νέο κωδικό');
      return;
    }
    setSavingPassword(true);
    try {
      await api.put('/client-admin/trainer/password', {
        current_password: currentPassword,
        new_password: newPassword,
      });
      setCurrentPassword('');
      setNewPassword('');
      toast.success('Ο κωδικός άλλαξε');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSavingPassword(false);
    }
  };

  const uploadPhoto = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    const fd = new FormData();
    fd.append('avatar', file);
    try {
      const r = await api.post('/client-admin/trainer/avatar', fd);
      setProfile(p => ({ ...p, avatar_url: r.data.avatar_url }));
      toast.success('Η φωτογραφία ενημερώθηκε');
    } catch {
      toast.error('Αποτυχία upload');
    } finally {
      setUploading(false);
    }
  };

  if (loading || !profile) {
    return <Layout title="Ρυθμίσεις" variant="trainer"><div className="loading">Φόρτωση...</div></Layout>;
  }

  const avatarSrc = profile.avatar_url
    ? (profile.avatar_url.startsWith('http') ? profile.avatar_url : `${API_BASE}${profile.avatar_url}`)
    : null;

  return (
    <Layout title="Ρυθμίσεις" variant="trainer">
      <div className="page-header">
        <div>
          <h1 className="page-title">Το προφίλ μου</h1>
          <p className="text-muted" style={{ margin: '6px 0 0' }}>
            Φωτογραφία, βιογραφικό και αλλαγή κωδικού
          </p>
        </div>
      </div>

      <div className="card" style={{ marginBottom: 16, padding: 20 }}>
        <div style={{ display: 'flex', gap: 20, alignItems: 'center', flexWrap: 'wrap' }}>
          <div style={{ position: 'relative' }}>
            {avatarSrc ? (
              <img src={avatarSrc} alt="" style={{ width: 96, height: 96, borderRadius: '50%', objectFit: 'cover' }} />
            ) : (
              <div style={{ width: 96, height: 96, borderRadius: '50%', background: colorHex, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '2rem', fontWeight: 700 }}>
                {profile.full_name?.[0]}
              </div>
            )}
          </div>
          <div>
            <div style={{ fontWeight: 700, fontSize: '1.1rem' }}>{profile.full_name}</div>
            <div className="text-muted" style={{ fontSize: '0.85rem' }}>{profile.role}</div>
            <div className="text-muted" style={{ fontSize: '0.82rem', marginTop: 4 }}>{profile.portal_email}</div>
            <label className="btn btn-secondary btn-sm" style={{ marginTop: 10, cursor: 'pointer' }}>
              <Upload size={14} /> {uploading ? '...' : 'Αλλαγή φωτό'}
              <input type="file" accept="image/*" style={{ display: 'none' }} onChange={uploadPhoto} />
            </label>
          </div>
        </div>
      </div>

      <div className="card" style={{ marginBottom: 16, padding: 20 }}>
        <h2 style={{ margin: '0 0 14px', fontSize: '1rem' }}>Βιογραφικό</h2>
        <div className="form-group">
          <label className="form-label">Χρώμα προφίλ</label>
          <input className="form-input" type="color" value={colorHex} onChange={e => setColorHex(e.target.value)} style={{ width: 80, padding: 4 }} />
        </div>
        <div className="form-group">
          <label className="form-label">Bio</label>
          <textarea className="form-input" rows={4} value={bio} onChange={e => setBio(e.target.value)} placeholder="Σύντομο βιογραφικό..." />
        </div>
        <button type="button" className="btn btn-primary btn-sm" disabled={savingProfile} onClick={saveProfile}>
          <Save size={14} /> {savingProfile ? '...' : 'Αποθήκευση προφίλ'}
        </button>
      </div>

      <div className="card" style={{ padding: 20 }}>
        <h2 style={{ margin: '0 0 14px', fontSize: '1rem' }}>Αλλαγή κωδικού</h2>
        <div className="form-grid-2" style={{ maxWidth: 480 }}>
          <div className="form-group">
            <label className="form-label">Τρέχων κωδικός</label>
            <input className="form-input" type="password" value={currentPassword} onChange={e => setCurrentPassword(e.target.value)} />
          </div>
          <div className="form-group">
            <label className="form-label">Νέος κωδικός</label>
            <input className="form-input" type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)} />
          </div>
        </div>
        <button type="button" className="btn btn-primary btn-sm" disabled={savingPassword} onClick={savePassword}>
          <Save size={14} /> {savingPassword ? '...' : 'Ενημέρωση κωδικού'}
        </button>
      </div>
    </Layout>
  );
}
