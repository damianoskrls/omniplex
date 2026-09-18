import { useState, useRef, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, User } from 'lucide-react';
import api from '../api/client';

function debounce(fn, ms) {
  let t;
  return (...args) => { clearTimeout(t); t = setTimeout(() => fn(...args), ms); };
}

export default function GlobalSearch() {
  const [val, setVal] = useState('');
  const [results, setResults] = useState([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [active, setActive] = useState(-1);
  const wrapRef = useRef(null);
  const navigate = useNavigate();

  const fetch = useCallback(debounce(async (q) => {
    if (!q.trim()) { setResults([]); setOpen(false); return; }
    setLoading(true);
    try {
      const r = await api.get(`/client-admin/search?q=${encodeURIComponent(q)}`);
      setResults(r.data || []);
      setOpen(true);
    } catch {
      setResults([]);
    } finally {
      setLoading(false);
    }
  }, 280), []);

  function onChange(e) {
    const q = e.target.value;
    setVal(q);
    setActive(-1);
    if (!q.trim()) { setResults([]); setOpen(false); return; }
    fetch(q);
  }

  function go(client) {
    setVal('');
    setResults([]);
    setOpen(false);
    navigate(`/clients/${client.id}`);
  }

  function onKeyDown(e) {
    if (!open || !results.length) return;
    if (e.key === 'ArrowDown') { e.preventDefault(); setActive(v => Math.min(v + 1, results.length - 1)); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(v => Math.max(v - 1, 0)); }
    else if (e.key === 'Enter') {
      e.preventDefault();
      if (active >= 0) go(results[active]);
    }
    else if (e.key === 'Escape') { setOpen(false); setVal(''); }
  }

  useEffect(() => {
    function click(e) { if (wrapRef.current && !wrapRef.current.contains(e.target)) setOpen(false); }
    document.addEventListener('mousedown', click);
    return () => document.removeEventListener('mousedown', click);
  }, []);

  return (
    <div ref={wrapRef} className="topbar-search-wrap">
      <div className={`topbar-search ${open && results.length ? 'topbar-search--open' : ''}`}>
        <Search size={15} className="topbar-search__icon" />
        <input
          className="topbar-search__input"
          placeholder="Αναζήτηση πελατών"
          value={val}
          onChange={onChange}
          onKeyDown={onKeyDown}
          onFocus={() => { if (results.length) setOpen(true); }}
          autoComplete="off"
        />
        {loading && <span className="topbar-search__spinner" />}
      </div>

      {open && results.length > 0 && (
        <div className="global-search-dropdown">
          {results.map((c, i) => (
            <button
              key={c.id}
              type="button"
              className={`global-search-item ${i === active ? 'global-search-item--active' : ''}`}
              onMouseEnter={() => setActive(i)}
              onClick={() => go(c)}
            >
              <div className="global-search-item__avatar">
                <User size={14} />
              </div>
              <div className="global-search-item__body">
                <div className="global-search-item__name">{c.full_name}</div>
                <div className="global-search-item__sub">{c.phone || c.email || '—'}</div>
              </div>
              {c.active_packages > 0 && (
                <span className="global-search-item__badge">{c.active_packages} πακέτα</span>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
