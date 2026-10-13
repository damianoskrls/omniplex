import { useState, useRef, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, User, X, Clock, Users, AlertTriangle, Calendar, TrendingUp, ArrowUpRight } from 'lucide-react';
import api from '../api/client';

const isMac = navigator.platform?.toLowerCase().includes('mac');
const STORAGE_KEY = 'gs_recent_v1';
const MAX_RECENT = 5;

// Direct navigation shortcuts — these always work, no API call needed
const QUICK_LINKS = [
  { label: 'Ανενεργοί πελάτες', icon: Users,          path: '/clients?status=inactive', desc: 'Χωρίς ενεργό πακέτο' },
  { label: 'Πελάτες σε κίνδυνο', icon: AlertTriangle, path: '/at-risk',                 desc: 'Κινδυνεύουν να αποχωρήσουν' },
  { label: 'Κρατήσεις',           icon: Calendar,      path: '/bookings',                desc: 'Πρόγραμμα μαθημάτων' },
  { label: 'Αναφορές',            icon: TrendingUp,    path: '/reports',                 desc: 'Στατιστικά & αναλύσεις' },
];

function getRecent() {
  try { return JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]'); } catch { return []; }
}
function addRecent(client) {
  const prev = getRecent().filter(r => r.id !== client.id);
  localStorage.setItem(STORAGE_KEY, JSON.stringify([client, ...prev].slice(0, MAX_RECENT)));
}
function removeRecent(id) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(getRecent().filter(r => r.id !== id)));
}

function debounce(fn, ms) {
  let t;
  return (...args) => { clearTimeout(t); t = setTimeout(() => fn(...args), ms); };
}

export default function GlobalSearch() {
  const [val, setVal]         = useState('');
  const [results, setResults] = useState([]);
  const [open, setOpen]       = useState(false);
  const [loading, setLoading] = useState(false);
  const [active, setActive]   = useState(-1);
  const [recent, setRecent]   = useState([]);
  const wrapRef  = useRef(null);
  const inputRef = useRef(null);
  const navigate = useNavigate();

  const doFetch = useCallback(debounce(async (q) => {
    if (!q.trim()) { setResults([]); return; }
    setLoading(true);
    try {
      const r = await api.get(`/client-admin/search?q=${encodeURIComponent(q)}`);
      setResults(r.data || []);
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
    if (!q.trim()) { setResults([]); return; }
    doFetch(q);
  }

  function goClient(client) {
    addRecent(client);
    setVal('');
    setResults([]);
    setOpen(false);
    navigate(`/clients/${client.id}`);
  }

  function goLink(path) {
    setVal('');
    setResults([]);
    setOpen(false);
    navigate(path);
  }

  function clear() {
    setVal('');
    setResults([]);
    setActive(-1);
    inputRef.current?.focus();
  }

  function onFocus() {
    setRecent(getRecent());
    setOpen(true);
  }

  const showEmpty     = open && !val.trim();
  const showResults   = open && val.trim().length > 0;
  const showNoResults = showResults && !loading && results.length === 0;
  const dropdownVisible = showEmpty || showResults;

  const maxNav = val.trim()
    ? results.length - 1
    : recent.length + QUICK_LINKS.length - 1;

  function onKeyDown(e) {
    if (!open) return;
    if (e.key === 'ArrowDown') {
      e.preventDefault(); setActive(v => Math.min(v + 1, maxNav));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault(); setActive(v => Math.max(v - 1, 0));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (val.trim()) {
        if (active >= 0 && results[active]) goClient(results[active]);
      } else {
        if (active >= 0 && active < recent.length) goClient(recent[active]);
        else if (active >= recent.length) goLink(QUICK_LINKS[active - recent.length].path);
      }
    } else if (e.key === 'Escape') {
      setOpen(false); setVal('');
    }
  }

  useEffect(() => {
    function click(e) {
      if (wrapRef.current && !wrapRef.current.contains(e.target)) setOpen(false);
    }
    document.addEventListener('mousedown', click);
    return () => document.removeEventListener('mousedown', click);
  }, []);

  useEffect(() => {
    function onKey(e) {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        inputRef.current?.focus();
        inputRef.current?.select();
      }
    }
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, []);

  return (
    <div ref={wrapRef} className="topbar-search-wrap">
      <div className={`topbar-search ${dropdownVisible ? 'topbar-search--open' : ''}`}>
        <Search size={15} className="topbar-search__icon" />
        <input
          ref={inputRef}
          className="topbar-search__input"
          placeholder="Αναζήτηση πελατών…"
          value={val}
          onChange={onChange}
          onKeyDown={onKeyDown}
          onFocus={onFocus}
          autoComplete="off"
        />
        {/* Fixed-width slot — prevents layout shift when switching between kbd/spinner/clear */}
        <div className="topbar-search__slot">
          {loading
            ? <span className="topbar-search__spinner" />
            : val
              ? <button type="button" className="topbar-search__clear" onClick={clear} aria-label="Καθαρισμός"><X size={13} /></button>
              : <kbd className="topbar-search__kbd">{isMac ? '⌘' : 'Ctrl'}K</kbd>
          }
        </div>
      </div>

      {dropdownVisible && (
        <div className="global-search-dropdown">

          {/* ── Empty state: Recent + Quick links ─────────────── */}
          {showEmpty && (
            <>
              {recent.length > 0 && (
                <div className="gs-section">
                  <div className="gs-section__label">
                    <Clock size={11} /> Πρόσφατα
                  </div>
                  {recent.map((c, i) => (
                    <button
                      key={c.id}
                      type="button"
                      className={`global-search-item ${i === active ? 'global-search-item--active' : ''}`}
                      onMouseEnter={() => setActive(i)}
                      onClick={() => goClient(c)}
                    >
                      <div className="global-search-item__avatar"><User size={14} /></div>
                      <div className="global-search-item__body">
                        <div className="global-search-item__name">{c.full_name}</div>
                        <div className="global-search-item__sub">{c.phone || c.email || '—'}</div>
                      </div>
                      <button
                        type="button"
                        className="gs-recent-remove"
                        onClick={e => { e.stopPropagation(); removeRecent(c.id); setRecent(getRecent()); }}
                        aria-label="Αφαίρεση"
                      ><X size={11} /></button>
                    </button>
                  ))}
                </div>
              )}

              <div className="gs-section">
                <div className="gs-section__label">
                  <ArrowUpRight size={11} /> Γρήγορη πρόσβαση
                </div>
                {QUICK_LINKS.map((ql, i) => {
                  const idx = recent.length + i;
                  const Icon = ql.icon;
                  return (
                    <button
                      key={ql.path}
                      type="button"
                      className={`global-search-item gs-quick-item ${idx === active ? 'global-search-item--active' : ''}`}
                      onMouseEnter={() => setActive(idx)}
                      onClick={() => goLink(ql.path)}
                    >
                      <div className="gs-quick-icon">
                        <Icon size={14} />
                      </div>
                      <div className="global-search-item__body">
                        <div className="global-search-item__name">{ql.label}</div>
                        <div className="global-search-item__sub">{ql.desc}</div>
                      </div>
                      <ArrowUpRight size={13} className="gs-quick-arrow" />
                    </button>
                  );
                })}
              </div>
            </>
          )}

          {/* ── Results while typing ────────────────────────── */}
          {showResults && !showNoResults && results.map((c, i) => (
            <button
              key={c.id}
              type="button"
              className={`global-search-item ${i === active ? 'global-search-item--active' : ''}`}
              onMouseEnter={() => setActive(i)}
              onClick={() => goClient(c)}
            >
              <div className="global-search-item__avatar"><User size={14} /></div>
              <div className="global-search-item__body">
                <div className="global-search-item__name">{c.full_name}</div>
                <div className="global-search-item__sub">{c.phone || c.email || '—'}</div>
              </div>
              {c.active_packages > 0 && (
                <span className="global-search-item__badge">{c.active_packages} πακέτα</span>
              )}
            </button>
          ))}

          {/* ── No results ──────────────────────────────────── */}
          {showNoResults && (
            <div className="gs-no-results">
              Δεν βρέθηκαν αποτελέσματα για <strong>«{val}»</strong>
            </div>
          )}

        </div>
      )}
    </div>
  );
}
