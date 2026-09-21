import { useEffect, useState } from 'react';
import api from '../api/client';

export default function JoinRequests() {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading]   = useState(true);
  const [filter, setFilter]     = useState('pending');
  const [error, setError]       = useState(null);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const { data } = await api.get(`/client-admin/join-requests?status=${filter}`);
      setRequests(data);
    } catch (e) {
      setError(e.response?.data?.error || 'Σφάλμα φόρτωσης');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, [filter]);

  async function decide(id, status) {
    try {
      await api.patch(`/client-admin/join-requests/${id}`, { status });
      setRequests(prev => prev.filter(r => r.id !== id));
    } catch (e) {
      alert(e.response?.data?.error || 'Σφάλμα');
    }
  }

  const statusLabel = { pending: 'Εκκρεμή', approved: 'Εγκεκριμένα', rejected: 'Απορριφθέντα', all: 'Όλα' };

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white mb-1">Αιτήματα Εγγραφής</h1>
        <p className="text-gray-400 text-sm">Νέοι χρήστες που ζήτησαν να γίνουν μέλη</p>
      </div>

      {/* Filter tabs */}
      <div className="flex gap-2 mb-6">
        {['pending', 'approved', 'rejected', 'all'].map(s => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`px-4 py-2 rounded-xl text-sm font-semibold transition-colors ${
              filter === s
                ? 'bg-[#B8F55E] text-black'
                : 'bg-[#1A1A22] text-gray-400 hover:text-white'
            }`}
          >
            {statusLabel[s]}
          </button>
        ))}
      </div>

      {error && (
        <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4 mb-4 text-red-400 text-sm">
          {error}
        </div>
      )}

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-6 h-6 border-2 border-[#B8F55E] border-t-transparent rounded-full animate-spin" />
        </div>
      ) : requests.length === 0 ? (
        <div className="text-center py-16 text-gray-500">Δεν υπάρχουν αιτήματα</div>
      ) : (
        <div className="space-y-3">
          {requests.map(r => (
            <div key={r.id} className="bg-[#1A1A22] border border-[#2A2A35] rounded-2xl p-4">
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <p className="font-semibold text-white">{r.full_name}</p>
                  <p className="text-sm text-gray-400">{r.email}</p>
                  {r.phone && <p className="text-sm text-gray-400">{r.phone}</p>}
                  <p className="text-xs text-gray-600 mt-1">
                    {new Date(r.created_at).toLocaleDateString('el-GR', { day: '2-digit', month: 'short', year: 'numeric' })}
                  </p>
                  {r.admin_note && (
                    <p className="text-xs text-gray-500 mt-1 italic">Σημείωση: {r.admin_note}</p>
                  )}
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  {r.status === 'pending' ? (
                    <>
                      <button
                        onClick={() => decide(r.id, 'approved')}
                        className="px-4 py-2 bg-[#B8F55E] text-black text-sm font-bold rounded-xl hover:bg-[#c9ff6e] transition-colors"
                      >
                        Έγκριση
                      </button>
                      <button
                        onClick={() => decide(r.id, 'rejected')}
                        className="px-4 py-2 bg-[#2A2A35] text-gray-300 text-sm font-semibold rounded-xl hover:bg-[#333345] transition-colors"
                      >
                        Απόρριψη
                      </button>
                    </>
                  ) : (
                    <span className={`px-3 py-1 rounded-full text-xs font-semibold ${
                      r.status === 'approved'
                        ? 'bg-green-500/15 text-green-400'
                        : 'bg-red-500/15 text-red-400'
                    }`}>
                      {r.status === 'approved' ? 'Εγκρίθηκε' : 'Απορρίφθηκε'}
                    </span>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
