import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout';
import Avatar from '../components/ui/Avatar';
import MessageBody from '../components/MessageBody';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Image as ImageIcon, MessageSquare, Search, Send, Smile, UserPlus, X } from 'lucide-react';
import { COMMON_EMOJIS } from '../utils/messageContent';

function formatWhen(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  const now = new Date();
  const sameDay = d.toDateString() === now.toDateString();
  if (sameDay) return d.toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' });
  return d.toLocaleDateString('el-GR', { day: 'numeric', month: 'short' });
}

function formatDateLabel(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const yesterday = new Date(today - 86400000);
  const msgDay = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  if (msgDay.getTime() === today.getTime()) return 'Σήμερα';
  if (msgDay.getTime() === yesterday.getTime()) return 'Χθες';
  return d.toLocaleDateString('el-GR', { weekday: 'long', day: 'numeric', month: 'long' });
}

function roleLabel(role) {
  if (role === 'admin') return 'Διαχείριση';
  if (role === 'trainer') return 'Γυμναστής';
  if (role === 'nutritionist') return 'Διατροφολόγος';
  if (role === 'client') return 'Πελάτης';
  return role || '';
}

function groupMessagesByDate(messages) {
  const groups = [];
  let currentDate = null;
  for (const m of messages) {
    const dateKey = m.created_at ? new Date(m.created_at).toDateString() : null;
    if (dateKey !== currentDate) {
      currentDate = dateKey;
      groups.push({ type: 'separator', label: formatDateLabel(m.created_at), key: `sep-${m.id}` });
    }
    groups.push({ type: 'message', message: m, key: m.id });
  }
  return groups;
}

export default function Messages() {
  const [searchParams, setSearchParams] = useSearchParams();
  const pendingClientId = searchParams.get('client');
  const handledClientRef = useRef(null);
  const [threads, setThreads] = useState([]);
  const [contacts, setContacts] = useState([]);
  const [activeThread, setActiveThread] = useState(null);
  const [messages, setMessages] = useState([]);
  const [loadingThreads, setLoadingThreads] = useState(true);
  const [loadingChat, setLoadingChat] = useState(false);
  const [sending, setSending] = useState(false);
  const [uploadingImage, setUploadingImage] = useState(false);
  const [showEmoji, setShowEmoji] = useState(false);
  const [draft, setDraft] = useState('');
  const [search, setSearch] = useState('');
  const [contactSearch, setContactSearch] = useState('');
  const [showNew, setShowNew] = useState(false);
  const [loadingContacts, setLoadingContacts] = useState(false);
  const [unreadTotal, setUnreadTotal] = useState(0);
  const bottomRef = useRef(null);
  const activeThreadIdRef = useRef(null);
  const messagesRef = useRef([]);
  const textareaRef = useRef(null);
  const fileInputRef = useRef(null);

  useEffect(() => { activeThreadIdRef.current = activeThread?.id || null; }, [activeThread?.id]);
  useEffect(() => { messagesRef.current = messages; }, [messages]);

  const loadThreads = useCallback(async () => {
    try {
      const [tRes, uRes] = await Promise.all([
        api.get('/client-admin/messages/threads', { params: { q: search } }),
        api.get('/client-admin/messages/unread-count'),
      ]);
      setThreads(tRes.data || []);
      setUnreadTotal(uRes.data?.unread_count || 0);
    } catch {
      toast.error('Σφάλμα φόρτωσης συνομιλιών');
    } finally {
      setLoadingThreads(false);
    }
  }, [search]);

  const loadContacts = useCallback(async () => {
    setLoadingContacts(true);
    try {
      const r = await api.get('/client-admin/messages/contacts', { params: { q: contactSearch, limit: 100 } });
      setContacts(r.data || []);
    } catch { setContacts([]); }
    finally { setLoadingContacts(false); }
  }, [contactSearch]);

  useEffect(() => {
    loadThreads();
    const t = setInterval(loadThreads, 5000);
    return () => clearInterval(t);
  }, [loadThreads]);

  const refreshActiveChat = useCallback(async () => {
    const threadId = activeThreadIdRef.current;
    if (!threadId) return;
    try {
      const r = await api.get(`/client-admin/messages/threads/${threadId}`);
      const incoming = r.data.messages || [];
      const prev = messagesRef.current;
      const changed = incoming.length !== prev.length || incoming.some((m, i) => m.id !== prev[i]?.id);
      if (!changed) return;
      setMessages(incoming);
      setActiveThread(r.data.thread);
      const hasNewFromOther = incoming.length > prev.length && incoming.slice(prev.length).some((m) => !m.is_mine);
      if (hasNewFromOther) {
        await api.post(`/client-admin/messages/threads/${threadId}/read`);
        setThreads((list) => list.map((t) => (t.id === threadId ? { ...t, unread_count: 0 } : t)));
      }
      loadThreads();
    } catch { /* silent */ }
  }, [loadThreads]);

  useEffect(() => {
    if (!activeThread?.id) return undefined;
    refreshActiveChat();
    const t = setInterval(refreshActiveChat, 3000);
    return () => clearInterval(t);
  }, [activeThread?.id, refreshActiveChat]);

  useEffect(() => {
    if (!showNew) return;
    const t = setTimeout(loadContacts, 250);
    return () => clearTimeout(t);
  }, [showNew, loadContacts]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, activeThread?.id]);

  const openThread = async (threadId) => {
    setShowNew(false);
    setLoadingChat(true);
    try {
      const r = await api.get(`/client-admin/messages/threads/${threadId}`);
      setActiveThread(r.data.thread);
      setMessages(r.data.messages || []);
      await api.post(`/client-admin/messages/threads/${threadId}/read`);
      setThreads(prev => prev.map(t => (t.id === threadId ? { ...t, unread_count: 0 } : t)));
      setUnreadTotal(prev => Math.max(0, prev - (activeThread?.unread_count || 0)));
      loadThreads();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα φόρτωσης');
    } finally { setLoadingChat(false); }
  };

  useEffect(() => {
    if (!pendingClientId) { handledClientRef.current = null; return; }
    if (loadingThreads) return;
    if (handledClientRef.current === pendingClientId) return;
    const existing = threads.find((t) => t.client_user_id === pendingClientId);
    if (existing) {
      handledClientRef.current = pendingClientId;
      setSearchParams({}, { replace: true });
      openThread(existing.id);
      return;
    }
    handledClientRef.current = pendingClientId;
    setSearchParams({}, { replace: true });
    (async () => {
      setLoadingChat(true);
      try {
        const r = await api.post('/client-admin/messages/threads', { client_user_id: pendingClientId });
        setActiveThread(r.data.thread);
        setMessages(r.data.messages || []);
        await loadThreads();
      } catch (err) {
        handledClientRef.current = null;
        toast.error(err.response?.data?.error || 'Δεν μπορείς να ανοίξεις συνομιλία');
      } finally { setLoadingChat(false); }
    })();
  }, [pendingClientId, loadingThreads, threads, setSearchParams, loadThreads]);

  const contactOptions = useMemo(() => {
    const map = new Map();
    for (const c of contacts) { if (c?.client_user_id) map.set(c.client_user_id, c); }
    for (const t of threads) {
      if (!t?.client_user_id || map.has(t.client_user_id)) continue;
      map.set(t.client_user_id, { client_user_id: t.client_user_id, client_name: t.client_name, client_email: t.client_email, client_phone: t.client_phone });
    }
    const q = contactSearch.trim().toLowerCase();
    let list = Array.from(map.values());
    if (q) list = list.filter((c) => [c.client_name, c.client_email, c.client_phone].filter(Boolean).join(' ').toLowerCase().includes(q));
    return list.sort((a, b) => (a.client_name || '').localeCompare(b.client_name || '', 'el'));
  }, [contacts, threads, contactSearch]);

  const startWithContact = async (contact) => {
    setShowNew(false);
    setLoadingChat(true);
    try {
      const r = await api.post('/client-admin/messages/threads', { client_user_id: contact.client_user_id });
      setActiveThread(r.data.thread);
      setMessages(r.data.messages || []);
      await loadThreads();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Δεν μπορείς να ανοίξεις συνομιλία');
    } finally { setLoadingChat(false); }
  };

  const insertEmoji = (emoji) => {
    const el = textareaRef.current;
    if (!el) { setDraft((prev) => `${prev}${emoji}`); return; }
    const start = el.selectionStart ?? draft.length;
    const end = el.selectionEnd ?? draft.length;
    const next = `${draft.slice(0, start)}${emoji}${draft.slice(end)}`;
    setDraft(next);
    requestAnimationFrame(() => { el.focus(); const pos = start + emoji.length; el.setSelectionRange(pos, pos); });
  };

  const appendMessageLocally = (threadId, msg, preview) => {
    const now = new Date().toISOString();
    setMessages((prev) => [...prev, msg]);
    setActiveThread((prev) => (prev ? { ...prev, last_message_preview: preview, last_message_at: now } : prev));
    setThreads((prev) => prev.map((t) => (t.id === threadId ? { ...t, last_message_preview: preview, last_message_at: now } : t)));
  };

  const sendPayload = async (threadId, payload) => {
    const r = await api.post(`/client-admin/messages/threads/${threadId}/messages`, payload);
    return r.data.message;
  };

  const sendMessage = async (e) => {
    e?.preventDefault?.();
    const text = draft.trim();
    if (!text || !activeThread?.id || sending || uploadingImage) return;
    const threadId = activeThread.id;
    setSending(true);
    try {
      const msg = await sendPayload(threadId, { body: text });
      const preview = text.length > 200 ? `${text.slice(0, 197)}...` : text;
      appendMessageLocally(threadId, msg, preview);
      setDraft('');
      setShowEmoji(false);
      loadThreads();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Αποτυχία αποστολής');
    } finally { setSending(false); }
  };

  const onPickImage = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    const threadId = activeThread?.id;
    if (!file || !threadId || sending || uploadingImage) return;
    setUploadingImage(true);
    try {
      const form = new FormData();
      form.append('image', file);
      const uploadRes = await api.post(`/client-admin/messages/threads/${threadId}/upload`, form, { headers: { 'Content-Type': 'multipart/form-data' } });
      const attachmentUrl = uploadRes.data?.attachment_url;
      if (!attachmentUrl) throw new Error('Upload failed');
      const caption = draft.trim();
      const msg = await sendPayload(threadId, { body: caption, attachment_url: attachmentUrl, message_type: 'image' });
      appendMessageLocally(threadId, msg, caption ? `📷 ${caption}` : '📷 Φωτογραφία');
      setDraft('');
      setShowEmoji(false);
      loadThreads();
    } catch (err) {
      toast.error(err.response?.data?.error || err.message || 'Αποτυχία αποστολής εικόνας');
    } finally { setUploadingImage(false); }
  };

  const messageGroups = useMemo(() => groupMessagesByDate(messages), [messages]);

  const onlineStatus = activeThread?.is_online
    ? 'Online'
    : activeThread?.last_seen_at
      ? `Τελευταία είσοδος ${formatWhen(activeThread.last_seen_at)}`
      : null;

  return (
    <Layout title="Μηνύματα">
      <div className="msg-layout">
        {/* ── Left column: thread list ── */}
        <aside className="msg-sidebar">
          <div className="msg-sidebar__head">
            <div className="msg-sidebar__title">
              Μηνύματα
              {unreadTotal > 0 && <span className="msg-badge msg-badge--blue">{unreadTotal}</span>}
            </div>
            <button
              type="button"
              className={`msg-icon-btn ${showNew ? 'msg-icon-btn--active' : ''}`}
              onClick={() => setShowNew((v) => !v)}
              title="Νέα συνομιλία"
            >
              {showNew ? <X size={16} /> : <UserPlus size={16} />}
            </button>
          </div>

          <div className="msg-search">
            <Search size={14} />
            <input
              type="search"
              placeholder="Αναζήτηση..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          {showNew && (
            <div className="msg-new">
              <div className="msg-new__label">Νέα συνομιλία</div>
              <div className="msg-search msg-search--inner">
                <Search size={14} />
                <input
                  type="search"
                  placeholder="Αναζήτηση μέλους..."
                  value={contactSearch}
                  onChange={(e) => setContactSearch(e.target.value)}
                  autoFocus
                />
              </div>
              <div className="msg-thread-list">
                {loadingContacts ? (
                  <div className="msg-empty">Φόρτωση...</div>
                ) : contactOptions.length === 0 ? (
                  <div className="msg-empty">{contactSearch.trim() ? 'Δεν βρέθηκαν μέλη' : 'Δεν υπάρχουν διαθέσιμα μέλη'}</div>
                ) : contactOptions.map((c) => (
                  <button key={c.client_user_id} type="button" className="msg-thread" onClick={() => startWithContact(c)}>
                    <div className="msg-thread__avatar-wrap">
                      <Avatar name={c.client_name} size={40} />
                    </div>
                    <div className="msg-thread__body">
                      <div className="msg-thread__name">{c.client_name}</div>
                      <div className="msg-thread__preview">{c.client_email || c.client_phone || ''}</div>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          )}

          <div className="msg-thread-list">
            {loadingThreads ? (
              <div className="msg-empty">Φόρτωση...</div>
            ) : threads.length === 0 ? (
              <div className="msg-empty">Δεν υπάρχουν συνομιλίες.</div>
            ) : threads.map((t) => (
              <button
                key={t.id}
                type="button"
                className={`msg-thread ${activeThread?.id === t.id ? 'msg-thread--active' : ''} ${t.unread_count > 0 ? 'msg-thread--unread' : ''}`}
                onClick={() => openThread(t.id)}
              >
                <div className="msg-thread__avatar-wrap">
                  <Avatar name={t.client_name} image={t.client_avatar_url} size={40} />
                  {t.is_online && <span className="msg-online-dot" />}
                </div>
                <div className="msg-thread__body">
                  <div className="msg-thread__row">
                    <span className="msg-thread__name">{t.client_name}</span>
                    <span className="msg-thread__time">{formatWhen(t.last_message_at)}</span>
                  </div>
                  <div className="msg-thread__row">
                    <span className="msg-thread__preview">{t.last_message_preview || 'Χωρίς μηνύματα'}</span>
                    {t.unread_count > 0 && <span className="msg-badge">{t.unread_count}</span>}
                  </div>
                </div>
              </button>
            ))}
          </div>
        </aside>

        {/* ── Right column: chat area ── */}
        <section className="msg-chat">
          {!activeThread ? (
            <div className="msg-chat__empty">
              <MessageSquare size={44} strokeWidth={1.2} />
              <p>Επίλεξε συνομιλία ή ξεκίνα νέα<br />με ενεργό μέλος</p>
            </div>
          ) : (
            <>
              {/* Chat header */}
              <div className="msg-chat__head">
                <div className="msg-chat__head-avatar">
                  <Avatar name={activeThread.client_name} image={activeThread.client_avatar_url} size={40} />
                  {activeThread.is_online && <span className="msg-online-dot" />}
                </div>
                <div className="msg-chat__head-info">
                  <div className="msg-chat__head-name">{activeThread.client_name}</div>
                  {onlineStatus && (
                    <div className={`msg-chat__head-status ${activeThread.is_online ? 'msg-chat__head-status--online' : ''}`}>
                      {onlineStatus}
                    </div>
                  )}
                </div>
              </div>

              {/* Messages */}
              <div className="msg-chat__body">
                {loadingChat ? (
                  <div className="msg-empty">Φόρτωση μηνυμάτων...</div>
                ) : messages.length === 0 ? (
                  <div className="msg-empty">Στείλε το πρώτο μήνυμα</div>
                ) : messageGroups.map((item) => {
                  if (item.type === 'separator') {
                    return (
                      <div key={item.key} className="msg-date-sep">
                        <span>{item.label}</span>
                      </div>
                    );
                  }
                  const m = item.message;
                  return (
                    <div key={item.key} className={`msg-row ${m.is_mine ? 'msg-row--mine' : 'msg-row--theirs'}`}>
                      {!m.is_mine && (
                        <div className="msg-row__avatar">
                          <Avatar name={m.sender_name || activeThread.client_name} size={32} />
                        </div>
                      )}
                      <div className="msg-row__content">
                        {!m.is_mine && (
                          <div className="msg-row__sender">{m.sender_name || roleLabel(m.sender_role)}</div>
                        )}
                        <div className={`msg-bubble ${m.is_mine ? 'msg-bubble--mine' : 'msg-bubble--theirs'}`}>
                          <MessageBody
                            body={m.body}
                            messageType={m.message_type}
                            attachmentUrl={m.attachment_url}
                          />
                        </div>
                        <div className="msg-row__time">{formatWhen(m.created_at)}</div>
                      </div>
                    </div>
                  );
                })}
                <div ref={bottomRef} />
              </div>

              {/* Compose */}
              <form className="msg-compose" onSubmit={sendMessage}>
                {showEmoji && (
                  <div className="msg-emoji-panel">
                    {COMMON_EMOJIS.map((emoji) => (
                      <button key={emoji} type="button" className="msg-emoji-btn" onClick={() => insertEmoji(emoji)}>
                        {emoji}
                      </button>
                    ))}
                  </div>
                )}
                <div className="msg-compose__inner">
                  <button type="button" className="msg-compose__tool" onClick={() => setShowEmoji((v) => !v)} title="Emoji">
                    <Smile size={18} />
                  </button>
                  <button type="button" className="msg-compose__tool" onClick={() => fileInputRef.current?.click()} disabled={uploadingImage} title="Εικόνα">
                    <ImageIcon size={18} />
                  </button>
                  <input ref={fileInputRef} type="file" accept="image/jpeg,image/png,image/webp,image/gif" hidden onChange={onPickImage} />
                  <textarea
                    ref={textareaRef}
                    className="msg-compose__input"
                    rows={1}
                    placeholder="Γράψε μήνυμα..."
                    value={draft}
                    onChange={(e) => setDraft(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(e); }
                    }}
                    aria-label="Μήνυμα"
                  />
                  <button
                    type="submit"
                    className={`msg-compose__send ${draft.trim() ? 'msg-compose__send--active' : ''}`}
                    disabled={sending || uploadingImage || !draft.trim()}
                    aria-label="Αποστολή"
                  >
                    <Send size={16} />
                  </button>
                </div>
              </form>
            </>
          )}
        </section>
      </div>
    </Layout>
  );
}
