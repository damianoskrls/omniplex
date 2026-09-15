import { useEffect, useRef, useState, useCallback } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Heart, MessageCircle, Trash2, Send, Image as ImageIcon, Plus, X, AtSign } from 'lucide-react';
import { mediaUrl } from '../utils/media';
import { splitMessageSegments } from '../utils/messageContent';
import ImageLightbox from '../components/ImageLightbox';

function fmtDate(iso) {
  const d = new Date(iso);
  const now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return 'μόλις τώρα';
  if (diff < 3600) return `${Math.floor(diff / 60)} λ. πριν`;
  if (diff < 86400) return `${Math.floor(diff / 3600)} ω. πριν`;
  return d.toLocaleDateString('el-GR', { day: 'numeric', month: 'short' });
}

function Avatar({ name, image, size = 36 }) {
  const initials = (name || '?').split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase();
  return image
    ? <img src={mediaUrl(image)} alt={name} style={{ width: size, height: size, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }} />
    : <div style={{ width: size, height: size, borderRadius: '50%', background: '#cbd5e1', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: size * 0.36, color: '#475569', flexShrink: 0 }}>
        {initials}
      </div>;
}

// Reusable mention-aware textarea
function MentionTextarea({ value, onChange, onMentionsChange, mentionables, placeholder, rows = 3, style = {} }) {
  const [suggestions, setSuggestions] = useState([]);
  const [mentions, setMentions] = useState([]);
  const textareaRef = useRef();

  const handleChange = (e) => {
    const text = e.target.value;
    onChange(text);
    const cursor = e.target.selectionStart;
    const before = text.substring(0, cursor);
    const atIdx = before.lastIndexOf('@');
    if (atIdx >= 0 && (atIdx === 0 || /[\s\n]/.test(before[atIdx - 1]))) {
      const query = before.substring(atIdx + 1).toLowerCase();
      setSuggestions(mentionables.filter(m => m.full_name.toLowerCase().includes(query)).slice(0, 6));
    } else {
      setSuggestions([]);
    }
  };

  const insertMention = (person) => {
    const text = value;
    const cursor = textareaRef.current.selectionStart;
    const before = text.substring(0, cursor);
    const atIdx = before.lastIndexOf('@');
    const after = text.substring(cursor);
    const name = person.full_name;
    const newText = `${text.substring(0, atIdx)}@${name} ${after}`;
    onChange(newText);
    setSuggestions([]);
    const newMentions = [...mentions];
    if (!newMentions.find(m => m.user_id === person.user_id && m.staff_id === person.staff_id)) {
      newMentions.push(person);
    }
    setMentions(newMentions);
    onMentionsChange?.(newMentions);
    setTimeout(() => {
      textareaRef.current?.focus();
      const pos = atIdx + name.length + 2;
      textareaRef.current?.setSelectionRange(pos, pos);
    }, 0);
  };

  return (
    <div style={{ position: 'relative' }}>
      <textarea
        ref={textareaRef}
        className="form-input"
        rows={rows}
        placeholder={placeholder}
        value={value}
        onChange={handleChange}
        style={{ resize: 'vertical', marginBottom: suggestions.length ? 0 : 10, ...style }}
      />
      {suggestions.length > 0 && (
        <div style={{ position: 'absolute', left: 0, right: 0, background: '#fff', border: '1px solid #e2e8f0', borderRadius: 8, boxShadow: '0 4px 12px #0002', zIndex: 100, marginBottom: 10 }}>
          {suggestions.map((p, i) => (
            <div key={i} onMouseDown={e => { e.preventDefault(); insertMention(p); }}
              style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '7px 12px', cursor: 'pointer', borderBottom: i < suggestions.length - 1 ? '1px solid #f1f5f9' : 'none' }}
              onMouseEnter={e => e.currentTarget.style.background = '#f8fafc'}
              onMouseLeave={e => e.currentTarget.style.background = ''}>
              <Avatar name={p.full_name} size={26} />
              <span style={{ fontSize: '0.85rem', fontWeight: 600 }}>{p.full_name}</span>
              {p.staff_id && <span style={{ fontSize: '0.7rem', background: '#dbeafe', color: '#1d4ed8', padding: '1px 6px', borderRadius: 20 }}>Staff</span>}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function CommentBox({ postId, mentionables, onCommentAdded }) {
  const [body, setBody] = useState('');
  const [mentions, setMentions] = useState([]);
  const [sending, setSending] = useState(false);

  async function send(e) {
    e.preventDefault();
    if (!body.trim()) return;
    setSending(true);
    try {
      const r = await api.post(`/client-admin/community/admin/posts/${postId}/comments`, {
        body: body.trim(),
        mentions: mentions.length ? mentions : undefined,
      });
      setBody(''); setMentions([]);
      onCommentAdded?.(r.data);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSending(false);
    }
  }

  return (
    <form onSubmit={send} style={{ display: 'flex', gap: 8, alignItems: 'flex-end', marginTop: 10, borderTop: '1px solid #f1f5f9', paddingTop: 10 }}>
      <div style={{ flex: 1 }}>
        <MentionTextarea
          value={body}
          onChange={setBody}
          onMentionsChange={setMentions}
          mentionables={mentionables}
          placeholder="Γράψε σχόλιο... (@ για mention)"
          rows={1}
          style={{ marginBottom: 0 }}
        />
      </div>
      <button type="submit" className="btn btn-primary btn-sm" disabled={sending || !body.trim()} style={{ flexShrink: 0 }}>
        <Send size={13} />
      </button>
    </form>
  );
}

function PostCard({ post, onDelete, onDeleteComment, onPinChange, mentionables }) {
  const [expanded, setExpanded] = useState(false);
  const [comments, setComments] = useState(post.comments || []);
  const [lightboxSrc, setLightboxSrc] = useState(null);
  const [pinned, setPinned] = useState(!!post.is_pinned);
  const [showPinPicker, setShowPinPicker] = useState(false);
  const [pinUntil, setPinUntil] = useState(post.pinned_until ? post.pinned_until.slice(0, 10) : '');
  const [pinning, setPinning] = useState(false);
  const authorName = post.staff_name || post.user_name || 'Άγνωστος';
  const authorAvatar = post.staff_avatar || null;
  const isStaff = !!post.staff_id;

  async function handlePin() {
    if (pinned) {
      setPinning(true);
      try {
        await api.patch(`/client-admin/community/admin/posts/${post.id}/pin`, { pin: false });
        setPinned(false); setPinUntil(''); setShowPinPicker(false);
        onPinChange?.();
      } catch { toast.error('Σφάλμα'); }
      finally { setPinning(false); }
    } else {
      setShowPinPicker(true);
    }
  }

  async function confirmPin() {
    setPinning(true);
    try {
      await api.patch(`/client-admin/community/admin/posts/${post.id}/pin`, {
        pin: true,
        pinned_until: pinUntil ? `${pinUntil}T23:59:59` : null,
      });
      setPinned(true); setShowPinPicker(false);
      onPinChange?.();
    } catch { toast.error('Σφάλμα'); }
    finally { setPinning(false); }
  }

  return (
    <div className="card" style={{ marginBottom: 16, border: pinned ? '2px solid #f59e0b' : undefined }}>
      {pinned && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: '0.72rem', fontWeight: 700, color: '#d97706', marginBottom: 8 }}>
          📌 Καρφιτσωμένο{post.pinned_until ? ` μέχρι ${new Date(post.pinned_until).toLocaleDateString('el-GR')}` : ''}
        </div>
      )}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
        <Avatar name={authorName} image={authorAvatar} size={40} />
        <div style={{ flex: 1 }}>
          <div style={{ fontWeight: 700, fontSize: '0.9rem', color: '#1e293b' }}>
            {authorName}
            {isStaff && <span style={{ marginLeft: 6, fontSize: '0.7rem', background: '#dbeafe', color: '#1d4ed8', padding: '1px 7px', borderRadius: 20, fontWeight: 600 }}>Staff</span>}
          </div>
          <div style={{ fontSize: '0.75rem', color: '#94a3b8' }}>{fmtDate(post.created_at)}</div>
        </div>
        <button title={pinned ? 'Ξεκαρφίτσωμα' : 'Καρφίτσωμα'} disabled={pinning}
          style={{ background: 'none', border: 'none', cursor: 'pointer', color: pinned ? '#f59e0b' : '#94a3b8', padding: 4 }}
          onClick={handlePin}>
          📌
        </button>
        <button title="Διαγραφή post" style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#f87171', padding: 4 }}
          onClick={() => onDelete(post.id)}>
          <Trash2 size={15} />
        </button>
      </div>
      {showPinPicker && (
        <div style={{ background: '#fffbeb', border: '1px solid #fde68a', borderRadius: 10, padding: '10px 12px', marginBottom: 12, display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: '0.82rem', fontWeight: 600, color: '#92400e' }}>Καρφίτσωμα μέχρι:</span>
          <input type="date" className="form-input" value={pinUntil} onChange={e => setPinUntil(e.target.value)}
            min={new Date().toISOString().slice(0, 10)}
            style={{ width: 160, padding: '3px 8px', fontSize: '0.82rem' }} />
          <span style={{ fontSize: '0.75rem', color: '#92400e' }}>(αφήστε κενό για μόνιμο)</span>
          <button className="btn btn-primary btn-sm" onClick={confirmPin} disabled={pinning}>Καρφίτσωμα</button>
          <button className="btn btn-sm" onClick={() => setShowPinPicker(false)} style={{ background: '#e2e8f0' }}>Άκυρο</button>
        </div>
      )}

      {post.body && (
        <div style={{ fontSize: '0.9rem', color: '#374151', marginBottom: post.media?.length ? 10 : 0, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
          {splitMessageSegments(post.body).map((seg, i) => {
            if (seg.type === 'youtube') return (
              <div key={i} style={{ margin: '6px 0' }}>
                <div style={{ position: 'relative', paddingBottom: '56.25%', height: 0, borderRadius: 8, overflow: 'hidden' }}>
                  <iframe
                    src={`https://www.youtube-nocookie.com/embed/${seg.videoId}`}
                    title="YouTube video"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowFullScreen
                    style={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%', border: 'none' }}
                  />
                </div>
                <a href={seg.value} target="_blank" rel="noopener noreferrer" style={{ fontSize: '0.75rem', color: '#3b82f6', wordBreak: 'break-all' }}>{seg.value}</a>
              </div>
            );
            if (seg.type === 'link') return <a key={i} href={seg.value} target="_blank" rel="noopener noreferrer" style={{ color: '#3b82f6', wordBreak: 'break-all' }}>{seg.value}</a>;
            return <span key={i}>{seg.value}</span>;
          })}
        </div>
      )}

      {post.media?.length > 0 && (
        <div style={{ display: 'grid', gridTemplateColumns: post.media.length === 1 ? '1fr' : '1fr 1fr', gap: 4, borderRadius: 10, overflow: 'hidden', marginBottom: 10 }}>
          {post.media.map((m, i) => m.type === 'video'
            ? <video key={i} src={mediaUrl(m.url)} controls style={{ width: '100%', maxHeight: 300, objectFit: 'cover', background: '#000' }} />
            : (
              <button key={i} type="button" onClick={() => setLightboxSrc(mediaUrl(m.url))}
                style={{ padding: 0, border: 'none', background: 'none', cursor: 'pointer', display: 'block' }}>
                <img src={mediaUrl(m.url)} alt="" style={{ width: '100%', height: post.media.length === 1 ? 'auto' : 160, objectFit: 'cover', display: 'block' }} />
              </button>
            )
          )}
        </div>
      )}
      {lightboxSrc && <ImageLightbox src={lightboxSrc} onClose={() => setLightboxSrc(null)} />}

      <div style={{ display: 'flex', gap: 16, fontSize: '0.8rem', color: '#94a3b8', marginBottom: expanded ? 0 : 0 }}>
        <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}><Heart size={13} /> {post.reaction_count || 0}</span>
        <button style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#94a3b8', display: 'flex', alignItems: 'center', gap: 4, fontSize: '0.8rem', padding: 0 }}
          onClick={() => setExpanded(e => !e)}>
          <MessageCircle size={13} /> {comments.length} σχόλια
        </button>
      </div>

      {expanded && (
        <div style={{ marginTop: 10 }}>
          {comments.length > 0 && (
            <div style={{ borderTop: '1px solid #f1f5f9', paddingTop: 10, marginBottom: 4 }}>
              {comments.map(c => (
                <div key={c.id} style={{ display: 'flex', gap: 8, marginBottom: 8, alignItems: 'flex-start' }}>
                  <Avatar name={c.staff_name || c.user_name} image={c.staff_avatar} size={28} />
                  <div style={{ flex: 1, background: '#f8fafc', borderRadius: 10, padding: '6px 10px', fontSize: '0.82rem' }}>
                    <span style={{ fontWeight: 600 }}>{c.staff_name || c.user_name}</span>
                    <span style={{ color: '#64748b', marginLeft: 8 }}>{c.body}</span>
                  </div>
                  <button title="Διαγραφή σχολίου" style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#f87171', padding: 2, marginTop: 4 }}
                    onClick={() => { onDeleteComment(c.id, post.id); setComments(prev => prev.filter(x => x.id !== c.id)); }}>
                    <Trash2 size={12} />
                  </button>
                </div>
              ))}
            </div>
          )}
          <CommentBox postId={post.id} mentionables={mentionables} onCommentAdded={c => setComments(prev => [...prev, c])} />
        </div>
      )}
    </div>
  );
}

function NewPostForm({ onPosted, mentionables }) {
  const [body, setBody] = useState('');
  const [media, setMedia] = useState([]);
  const [mentions, setMentions] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const fileRef = useRef();

  async function uploadFiles(files) {
    setUploading(true);
    try {
      const form = new FormData();
      for (const f of files) form.append('files', f);
      const r = await api.post('/client-admin/community/admin/upload-media', form, { headers: { 'Content-Type': 'multipart/form-data' } });
      setMedia(prev => [...prev, ...(r.data.media || [])]);
    } catch {
      toast.error('Σφάλμα ανεβάσματος');
    } finally {
      setUploading(false);
    }
  }

  async function submit(e) {
    e.preventDefault();
    if (!body.trim() && !media.length) { toast.error('Γράψε κάτι ή πρόσθεσε εικόνα'); return; }
    setSubmitting(true);
    try {
      await api.post('/client-admin/community/admin/posts', {
        body: body.trim() || null,
        media,
        mentions: mentions.length ? mentions : undefined,
      });
      toast.success('Δημοσιεύτηκε!');
      setBody(''); setMedia([]); setMentions([]);
      onPosted?.();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="card" style={{ marginBottom: 24 }}>
      <div style={{ fontWeight: 700, fontSize: '0.95rem', marginBottom: 12, color: '#1e293b' }}>
        <Plus size={15} style={{ marginRight: 6 }} />Νέα ανάρτηση
      </div>
      <form onSubmit={submit}>
        <MentionTextarea
          value={body}
          onChange={setBody}
          onMentionsChange={setMentions}
          mentionables={mentionables}
          placeholder="Γράψε κάτι για τα μέλη σου... (@ για mention)"
        />

        {media.length > 0 && (
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 10 }}>
            {media.map((m, i) => (
              <div key={i} style={{ position: 'relative', width: 80, height: 80 }}>
                {m.type === 'video'
                  ? <video src={mediaUrl(m.url)} style={{ width: 80, height: 80, objectFit: 'cover', borderRadius: 8 }} />
                  : <img src={mediaUrl(m.url)} alt="" style={{ width: 80, height: 80, objectFit: 'cover', borderRadius: 8 }} />
                }
                <button type="button" onClick={() => setMedia(prev => prev.filter((_, j) => j !== i))}
                  style={{ position: 'absolute', top: 2, right: 2, background: '#0008', border: 'none', borderRadius: '50%', width: 18, height: 18, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', color: '#fff' }}>
                  <X size={10} />
                </button>
              </div>
            ))}
          </div>
        )}

        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <input ref={fileRef} type="file" accept="image/*,video/*" multiple hidden onChange={e => e.target.files?.length && uploadFiles(Array.from(e.target.files))} />
          <button type="button" className="btn btn-secondary btn-sm" onClick={() => fileRef.current?.click()} disabled={uploading}>
            <ImageIcon size={14} /> {uploading ? 'Ανέβασμα...' : 'Εικόνα/Βίντεο'}
          </button>
          <div style={{ flex: 1 }} />
          <button type="submit" className="btn btn-primary" disabled={submitting}>
            <Send size={14} /> Δημοσίευση
          </button>
        </div>
      </form>
    </div>
  );
}

export default function Community() {
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [nextCursor, setNextCursor] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [mentionables, setMentionables] = useState([]);

  async function load(cursor = null) {
    if (!cursor) setLoading(true); else setLoadingMore(true);
    try {
      const r = await api.get('/client-admin/community/admin/posts', { params: { cursor, limit: 20 } });
      const data = r.data;
      setPosts(prev => cursor ? [...prev, ...data.posts] : data.posts);
      setNextCursor(data.next_cursor || null);
    } catch {
      toast.error('Σφάλμα φόρτωσης');
    } finally {
      setLoading(false); setLoadingMore(false);
    }
  }

  useEffect(() => {
    load();
    api.get('/client-admin/community/admin/mentionables')
      .then(r => setMentionables(r.data.mentionables || []))
      .catch(() => {});
  }, []);

  async function deletePost(id) {
    if (!window.confirm('Να διαγραφεί η ανάρτηση;')) return;
    await api.delete(`/client-admin/community/admin/posts/${id}`);
    setPosts(prev => prev.filter(p => p.id !== id));
    toast.success('Διαγράφηκε');
  }

  async function deleteComment(commentId, postId) {
    if (!window.confirm('Να διαγραφεί το σχόλιο;')) return;
    await api.delete(`/client-admin/community/admin/comments/${commentId}`);
    setPosts(prev => prev.map(p => p.id === postId
      ? { ...p, comments: p.comments.filter(c => c.id !== commentId) }
      : p));
  }

  return (
    <Layout title="Κοινότητα">
      <div className="page-header">
        <h1 className="page-title">Κοινότητα</h1>
        <p className="text-muted" style={{ fontSize: '0.85rem', marginTop: 4 }}>
          Κοινός χώρος αναρτήσεων για τα μέλη σου
        </p>
      </div>

      <div style={{ maxWidth: 680, margin: '0 auto' }}>
        <NewPostForm onPosted={() => load()} mentionables={mentionables} />

        {loading ? (
          <div className="loading">Φόρτωση...</div>
        ) : posts.length === 0 ? (
          <div style={{ textAlign: 'center', padding: 40, color: '#94a3b8' }}>Δεν υπάρχουν αναρτήσεις ακόμα</div>
        ) : (
          <>
            {posts.map(p => (
              <PostCard key={p.id} post={p} onDelete={deletePost} onDeleteComment={deleteComment} onPinChange={() => load()} mentionables={mentionables} />
            ))}
            {nextCursor && (
              <div style={{ textAlign: 'center', padding: 16 }}>
                <button className="btn btn-secondary" onClick={() => load(nextCursor)} disabled={loadingMore}>
                  {loadingMore ? 'Φόρτωση...' : 'Περισσότερα'}
                </button>
              </div>
            )}
          </>
        )}
      </div>
    </Layout>
  );
}
