import { useEffect, useRef, useState } from 'react';
import { Image, Upload, Trash2, X } from 'lucide-react';
import api from '../api/client';

export default function GymPhotos() {
  const [photos, setPhotos]     = useState([]);
  const [loading, setLoading]   = useState(true);
  const [uploading, setUploading] = useState(false);
  const [error, setError]       = useState(null);
  const inputRef = useRef();

  async function load() {
    setLoading(true);
    try {
      const r = await api.get('/client-admin/gym-photos');
      setPhotos(r.data);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []);

  async function handleUpload(e) {
    const files = Array.from(e.target.files || []);
    if (!files.length) return;
    setUploading(true); setError(null);
    try {
      for (const file of files) {
        const fd = new FormData();
        fd.append('photo', file);
        await api.post('/client-admin/gym-photos/upload', fd, {
          headers: { 'Content-Type': 'multipart/form-data' },
        });
      }
      await load();
    } catch (err) {
      setError(err.response?.data?.error || err.message);
    } finally {
      setUploading(false);
      if (inputRef.current) inputRef.current.value = '';
    }
  }

  async function handleDelete(id) {
    if (!confirm('Διαγραφή φωτογραφίας;')) return;
    try {
      await api.delete(`/client-admin/gym-photos/${id}`);
      setPhotos(p => p.filter(x => x.id !== id));
    } catch (err) {
      setError(err.response?.data?.error || err.message);
    }
  }

  return (
    <div className="max-w-4xl mx-auto p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Image className="text-indigo-500" size={24} />
          <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Φωτογραφίες Γυμναστηρίου</h1>
            <p className="text-sm text-gray-500">Εικόνες που βλέπουν οι χρήστες στο προφίλ του γυμναστηρίου</p>
          </div>
        </div>
        <button
          onClick={() => inputRef.current?.click()}
          disabled={uploading}
          className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-xl transition-colors disabled:opacity-50"
        >
          <Upload size={16} />
          {uploading ? 'Μεταφόρτωση…' : 'Προσθήκη'}
        </button>
        <input ref={inputRef} type="file" accept="image/*" multiple className="hidden" onChange={handleUpload} />
      </div>

      {error && (
        <div className="flex items-center gap-2 p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl text-red-600 text-sm">
          <X size={16} /> {error}
        </div>
      )}

      {loading ? (
        <div className="text-center text-gray-400 py-12">Φόρτωση…</div>
      ) : photos.length === 0 ? (
        <div
          onClick={() => inputRef.current?.click()}
          className="border-2 border-dashed border-gray-300 dark:border-gray-700 rounded-2xl p-16 flex flex-col items-center gap-3 cursor-pointer hover:border-indigo-400 transition-colors"
        >
          <Image size={40} className="text-gray-300 dark:text-gray-600" />
          <p className="text-gray-500 font-medium">Δεν υπάρχουν φωτογραφίες</p>
          <p className="text-sm text-gray-400">Κλικ για μεταφόρτωση εικόνων (JPG, PNG, WebP)</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
          {photos.map(p => (
            <div key={p.id} className="relative group rounded-xl overflow-hidden aspect-video bg-gray-100 dark:bg-gray-800">
              <img src={p.url} alt="" className="w-full h-full object-cover" />
              <button
                onClick={() => handleDelete(p.id)}
                className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity p-1.5 bg-red-500 hover:bg-red-600 text-white rounded-lg"
              >
                <Trash2 size={14} />
              </button>
            </div>
          ))}
          <div
            onClick={() => inputRef.current?.click()}
            className="aspect-video border-2 border-dashed border-gray-300 dark:border-gray-700 rounded-xl flex flex-col items-center justify-center gap-2 cursor-pointer hover:border-indigo-400 transition-colors"
          >
            <Upload size={20} className="text-gray-400" />
            <span className="text-xs text-gray-400">Προσθήκη</span>
          </div>
        </div>
      )}
    </div>
  );
}
