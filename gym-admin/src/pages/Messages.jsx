import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout';
import Avatar from '../components/ui/Avatar';
import MessageBody from '../components/MessageBody';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Image as ImageIcon, MessageSquare, Search, Send, Smile, UserPlus } from 'lucide-react';
import { COMMON_EMOJIS } from '../utils/messageContent';

function formatWhen(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  const now = new Date();
  const sameDay = d.toDateString() === now.toDateString();
  if (sameDay) {
    return d.toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' });
  }
  return d.toLocaleDateString('el-GR', { day: 'numeric', month: 'short' });
}

function roleLabel(role) {
  if (role === 'admin') return 'Διαχείριση';
  if (role === 'trainer') return 'Γυμναστής';
  if (role === 'nutritionist') return 'Διατροφολόγος';
  if (role === 'client') return 'Πελάτης';
  return role || '';
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

  useEffect(() => {
    activeThreadIdRef.current = activeThread?.id || null;
  }, [activeThread?.id]);

  useEffect(() => {
    messagesRef.current = messages;
  }, [messages]);

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
      const r = await api.get('/client-admin/messages/contacts', {
        params: { q: contactSearch, limit: 100 },
      });
      setContacts(r.data || []);
    } catch {
      setContacts([]);
    } finally {
      setLoadingContacts(false);
    }
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
      const changed = incoming.length !== prev.length
        || incoming.some((m, i) => m.id !== prev[i]?.id);
      if (!changed) return;

      setMessages(incoming);
      setActiveThread(r.data.thread);
      const hasNewFromOther = incoming.length > prev.length
        && incoming.slice(prev.length).some((m) => !m.is_mine);
      if (hasNewFromOther) {
        await api.post(`/client-admin/messages/threads/${threadId}/read`);
        setThreads((list) => list.map((t) => (
          t.id === threadId ? { ...t, unread_count: 0 } : t
        )));
      }
      loadThreads();
    } catch {
      /* silent poll failure */
    }
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
      setThreads(prev => prev.map(t => (
        t.id === threadId ? { ...t, unread_count: 0 } : t
      )));
      setUnreadTotal(prev => Math.max(0, prev - (activeThread?.unread_count || 0)));
      loadThreads();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα φόρτωσης');
    } finally {
      setLoadingChat(false);
    }
  };

  useEffect(() => {
    if (!pendingClientId) {
      handledClientRef.current = null;
      return;
    }
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
        const r = await api.post('/client-admin/messages/threads', {
          client_user_id: pendingClientId,
        });
        setActiveThread(r.data.thread);
        setMessages(r.data.messages || []);
        await loadThreads();
      } catch (err) {
        handledClientRef.current = null;
        toast.error(err.response?.data?.error || 'Δεν μπορείς να ανοίξεις συνομιλία');
      } finally {
        setLoadingChat(false);
      }
    })();
  }, [pendingClientId, loadingThreads, threads, setSearchParams, loadThreads]);

  const contactOptions = useMemo(() => {
    const map = new Map();
    for (const c of contacts) {
      if (c?.client_user_id) map.set(c.client_user_id, c);
    }
    for (const t of threads) {
      if (!t?.client_user_id || map.has(t.client_user_id)) continue;
      map.set(t.client_user_id, {
        client_user_id: t.client_user_id,
        client_name: t.client_name,
        client_email: t.client_email,
        client_phone: t.client_phone,
      });
    }
    const q = contactSearch.trim().toLowerCase();
    let list = Array.from(map.values());
    if (q) {
      list = list.filter((c) => {
        const hay = [c.client_name, c.client_email, c.client_phone]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        return hay.includes(q);
      });
    }
    return list.sort((a, b) => (a.client_name || '').localeCompare(b.client_name || '', 'el'));
  }, [contacts, threads, contactSearch]);

  const startWithContact = async (contact) => {
    setShowNew(false);
    setLoadingChat(true);
    try {
      const r = await api.post('/client-admin/messages/threads', {
        client_user_id: contact.client_user_id,
      });
      setActiveThread(r.data.thread);
      setMessages(r.data.messages || []);
      await loadThreads();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Δεν μπορείς να ανοίξεις συνομιλία');
    } finally {
      setLoadingChat(false);
    }
  };

  const insertEmoji = (emoji) => {
    const el = textareaRef.current;
    if (!el) {
      setDraft((prev) => `${prev}${emoji}`);
      return;
    }
    const start = el.selectionStart ?? draft.length;
    const end = el.selectionEnd ?? draft.length;
    const next = `${draft.slice(0, start)}${emoji}${draft.slice(end)}`;
    setDraft(next);
    requestAnimationFrame(() => {
      el.focus();
      const pos = start + emoji.length;
      el.setSelectionRange(pos, pos);
    });
  };

  const appendMessageLocally = (threadId, msg, preview) => {
    const now = new Date().toISOString();
    setMessages((prev) => [...prev, msg]);
    setActiveThread((prev) => (prev ? {
      ...prev,
      last_message_preview: preview,
      last_message_at: now,
    } : prev));
    setThreads((prev) => prev.map((t) => (
      t.id === threadId
        ? { ...t, last_message_preview: preview, last_message_at: now }
        : t
    )));
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
    } finally {
      setSending(false);
    }
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
      const uploadRes = await api.post(`/client-admin/messages/threads/${threadId}/upload`, form, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const attachmentUrl = uploadRes.data?.attachment_url;
      if (!attachmentUrl) throw new Error('Upload failed');

      const caption = draft.trim();
      const msg = await sendPayload(threadId, {
        body: caption,
        attachment_url: attachmentUrl,
        message_type: 'image',
      });
      appendMessageLocally(threadId, msg, caption ? `📷 ${caption}` : '📷 Φωτογραφία');
      setDraft('');
      setShowEmoji(false);
      loadThreads();
    } catch (err) {
      toast.error(err.response?.data?.error || err.message || 'Αποτυχία αποστολής εικόνας');
    } finally {
      setUploadingImage(false);
    }
  };

  return (
    <Layout title="Μηνύματα">
      <div className="messages-layout">
        <aside className="messages-sidebar card card--flush">
          <div className="messages-sidebar__head">
            <div className="messages-sidebar__title">
              <MessageSquare size={18} />
              Συνομιλίες
              {unreadTotal > 0 && <span className="messages-badge">{unreadTotal}</span>}
            </div>
            <button
              type="button"
              className={`btn btn-secondary btn-sm ${showNew ? 'messages-new-toggle--active' : ''}`}
              onClick={() => setShowNew((v) => !v)}
              title="Νέα συνομιλία"
              aria-pressed={showNew}
            >
              <UserPlus size={14} />
            </button>
          </div>

          <div className="messages-search">
            <Search size={16} />
            <input
              type="search"
              placeholder="Αναζήτηση πελάτη..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          {showNew && (
            <div className="messages-new">
              <div className="messages-new__head">
                <span className="messages-new__title">Νέα συνομιλία</span>
                <button
                  type="button"
                  className="messages-new__close"
                  onClick={() => setShowNew(false)}
                  aria-label="Κλείσιμο"
                >
                  ×
                </button>
              </div>
              <div className="messages-new__search">
                <Search size={16} />
                <input
                  type="search"
                  placeholder="Αναζήτηση ενεργού μέλους..."
                  value={contactSearch}
                  onChange={(e) => setContactSearch(e.target.value)}
                  autoFocus
                />
              </div>
              <div className="messages-new__list">
                {loadingContacts ? (
                  <div className="messages-empty">Φόρτωση πελατών...</div>
                ) : contactOptions.length === 0 ? (
                  <div className="messages-empty">
                    {contactSearch.trim()
                      ? 'Δεν βρέθηκαν πελάτες με αυτή την αναζήτηση'
                      : 'Δεν υπάρχουν διαθέσιμοι πελάτες'}
                  </div>
                ) : contactOptions.map((c) => (
                  <button
                    key={c.client_user_id}
                    type="button"
                    className="messages-thread"
                    onClick={() => startWithContact(c)}
                  >
                    <Avatar name={c.client_name} size={40} />
                    <div className="messages-thread__meta">
                      <div className="messages-thread__name">{c.client_name}</div>
                      <div className="messages-thread__preview">{c.client_email || c.client_phone || ''}</div>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          )}

          <div className="messages-thread-list">
            {loadingThreads ? (
              <div className="messages-empty">Φόρτωση...</div>
            ) : threads.length === 0 ? (
              <div className="messages-empty">
                Δεν υπάρχουν συνομιλίες ακόμα.
                <br />
                Πάτα + για νέα επικοινωνία με ενεργό μέλος.
              </div>
            ) : threads.map((t) => (
              <button
                key={t.id}
                type="button"
                className={`messages-thread ${activeThread?.id === t.id ? 'messages-thread--active' : ''}`}
                onClick={() => openThread(t.id)}
              >
                <Avatar name={t.client_name} image={t.client_avatar_url} size={44} />
                <div className="messages-thread__meta">
                  <div className="messages-thread__row">
                    <span className="messages-thread__name">{t.client_name}</span>
                    <span className="messages-thread__time">{formatWhen(t.last_message_at)}</span>
                  </div>
                  <div className="messages-thread__row">
                    <span className="messages-thread__preview">
                      {t.last_message_preview || 'Χωρίς μηνύματα'}
                    </span>
                    {t.unread_count > 0 && (
                      <span className="messages-thread__unread">{t.unread_count}</span>
                    )}
                  </div>
                </div>
              </button>
            ))}
          </div>
        </aside>

        <section className="messages-chat card card--flush">
          {!activeThread ? (
            <div className="messages-chat__empty">
              <MessageSquare size={40} strokeWidth={1.25} />
              <p>Επίλεξε συνομιλία ή ξεκίνα νέα με ενεργό μέλος</p>
            </div>
          ) : (
            <>
              <div className="messages-chat__head">
                <Avatar name={activeThread.client_name} image={activeThread.client_avatar_url} size={44} />
                <div>
                  <div className="messages-chat__name">{activeThread.client_name}</div>
                  <div className="messages-chat__sub">
                    {[activeThread.client_email, activeThread.client_phone].filter(Boolean).join(' · ')}
                  </div>
                </div>
              </div>

              <div className="messages-chat__body">
                {loadingChat ? (
                  <div className="messages-empty">Φόρτωση μηνυμάτων...</div>
                ) : messages.length === 0 ? (
                  <div className="messages-empty">Στείλε το πρώτο μήνυμα</div>
                ) : messages.map((m) => (
                  <div
                    key={m.id}
                    className={`messages-bubble ${m.is_mine ? 'messages-bubble--mine' : 'messages-bubble--theirs'}`}
                  >
                    {!m.is_mine && (
                      <div className="messages-bubble__sender">
                        {m.sender_name || roleLabel(m.sender_role)}
                      </div>
                    )}
                    <MessageBody
                      body={m.body}
                      messageType={m.message_type}
                      attachmentUrl={m.attachment_url}
                    />
                    <div className="messages-bubble__time">{formatWhen(m.created_at)}</div>
                  </div>
                ))}
                <div ref={bottomRef} />
              </div>

              <form className="messages-compose" onSubmit={sendMessage}>
                {showEmoji && (
                  <div className="messages-emoji-panel">
                    {COMMON_EMOJIS.map((emoji) => (
                      <button
                        key={emoji}
                        type="button"
                        className="messages-emoji-btn"
                        onClick={() => insertEmoji(emoji)}
                      >
                        {emoji}
                      </button>
                    ))}
                  </div>
                )}
                <div className="messages-compose__inner">
                  <div className="messages-compose__tools">
                    <button
                      type="button"
                      className="messages-compose__tool"
                      onClick={() => setShowEmoji((v) => !v)}
                      title="Emoji"
                    >
                      <Smile size={18} />
                    </button>
                    <button
                      type="button"
                      className="messages-compose__tool"
                      onClick={() => fileInputRef.current?.click()}
                      disabled={uploadingImage}
                      title="Εικόνα"
                    >
                      <ImageIcon size={18} />
                    </button>
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/jpeg,image/png,image/webp,image/gif"
                      hidden
                      onChange={onPickImage}
                    />
                  </div>
                  <textarea
                    ref={textareaRef}
                    className="messages-compose__input"
                    rows={1}
                    placeholder="Γράψε μήνυμα..."
                    value={draft}
                    onChange={(e) => setDraft(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' && !e.shiftKey) {
                        e.preventDefault();
                        sendMessage(e);
                      }
                    }}
                    aria-label="Μήνυμα"
                  />
                  <button
                    type="submit"
                    className="messages-compose__send"
                    disabled={sending || uploadingImage || !draft.trim()}
                    aria-label="Αποστολή"
                    title="Αποστολή"
                  >
                    <Send size={18} />
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
