import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Settings, MapPin, Users } from 'lucide-react';
import Layout from '../components/Layout';
import api from '../api/client';
import { useBranch } from '../context/BranchContext';

export default function StaffAvailabilityManager() {
  const { activeBranch, activeBranchId, branches } = useBranch() || {};
  const [staff, setStaff] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    setLoading(true);
    api.get('/client-admin/staff')
      .then(r => setStaff((r.data || []).filter(s => s.is_active !== 0)))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [activeBranchId]);

  const grouped = activeBranchId
    ? [{ branch: activeBranch, members: staff }]
    : (branches || []).map(b => ({
        branch: b,
        members: staff.filter(s => s.location_ids?.includes(String(b.id))),
      }));

  return (
    <Layout title="Διαθεσιμότητα Προσωπικού">
      <div className="page-header">
        <div>
          <h1 className="page-title">
            <Users size={20} style={{ marginRight: 8, verticalAlign: 'middle' }} />
            Διαθεσιμότητα Προσωπικού
          </h1>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
            <MapPin size={13} style={{ color: 'var(--text-secondary, #888)' }} />
            <span style={{ fontSize: '0.82rem', color: 'var(--text-secondary, #888)' }}>
              {activeBranch ? activeBranch.name : 'Όλα τα καταστήματα'}
            </span>
          </div>
        </div>
      </div>

      {loading ? (
        <div className="text-muted" style={{ textAlign: 'center', padding: '40px 0' }}>Φόρτωση…</div>
      ) : activeBranchId ? (
        staff.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '40px 0', border: '2px dashed var(--border, #e5e7eb)', borderRadius: 12 }}>
            <p className="text-muted">Δεν υπάρχει προσωπικό ανατεθειμένο σε αυτό το κατάστημα</p>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 16 }}>
            {staff.map(s => <StaffCard key={s.id} staff={s} onNavigate={() => navigate(`/staff/${s.id}`)} />)}
          </div>
        )
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 28 }}>
          {grouped.map(({ branch, members }) => (
            <div key={branch.id}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
                <MapPin size={14} style={{ color: 'var(--tenant-primary, #16a34a)' }} />
                <span style={{ fontWeight: 700, fontSize: '1rem' }}>{branch.name}</span>
                <span style={{ fontSize: '0.8rem', color: 'var(--text-secondary, #888)' }}>({members.length} μέλη)</span>
              </div>
              {members.length === 0 ? (
                <div style={{ padding: 16, border: '2px dashed var(--border, #e5e7eb)', borderRadius: 10, fontSize: '0.85rem', color: 'var(--text-secondary, #888)' }}>
                  Δεν υπάρχει προσωπικό ανατεθειμένο σε αυτό το κατάστημα
                </div>
              ) : (
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 12 }}>
                  {members.map(s => <StaffCard key={s.id} staff={s} onNavigate={() => navigate(`/staff/${s.id}`)} />)}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </Layout>
  );
}

function StaffCard({ staff: s, onNavigate }) {
  return (
    <div className="card" style={{ padding: 16 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
        {s.avatar_url ? (
          <img src={s.avatar_url} alt="" style={{ width: 40, height: 40, borderRadius: '50%', objectFit: 'cover' }} />
        ) : (
          <div style={{ width: 40, height: 40, borderRadius: '50%', background: s.color_hex || '#6366f1', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontWeight: 700, fontSize: '1rem' }}>
            {s.full_name?.charAt(0).toUpperCase()}
          </div>
        )}
        <div>
          <div style={{ fontWeight: 600 }}>{s.full_name}</div>
          <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary, #888)' }}>{s.role}</div>
        </div>
      </div>
      <button className="btn btn-secondary btn-sm" style={{ width: '100%' }} onClick={onNavigate}>
        <Settings size={14} /> Ρυθμίσεις &amp; Διαθεσιμότητα
      </button>
    </div>
  );
}
