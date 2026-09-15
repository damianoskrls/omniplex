import { useState } from 'react';
import { mediaUrl } from '../utils/media';
import { splitMessageSegments } from '../utils/messageContent';
import ImageLightbox from './ImageLightbox';

function renderTextSegments(text) {
  return splitMessageSegments(text).map((seg, i) => {
    if (seg.type === 'text') {
      return <span key={i}>{seg.value}</span>;
    }
    if (seg.type === 'youtube') {
      return (
        <div key={i} className="message-body__youtube">
          <iframe
            src={`https://www.youtube-nocookie.com/embed/${seg.videoId}`}
            title="YouTube video"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowFullScreen
          />
          <a href={seg.value} target="_blank" rel="noopener noreferrer" className="message-body__link">
            {seg.value}
          </a>
        </div>
      );
    }
    return (
      <a key={i} href={seg.value} target="_blank" rel="noopener noreferrer" className="message-body__link">
        {seg.value}
      </a>
    );
  });
}

export default function MessageBody({ body, messageType, attachmentUrl }) {
  const [lightboxSrc, setLightboxSrc] = useState(null);
  const caption = (body || '').trim();

  if (messageType === 'image') {
    if (!attachmentUrl) {
      return (
        <div className="message-body">
          <div className="message-body__expired">Η εικόνα δεν είναι πια διαθέσιμη (έληξε μετά από 24 ώρες)</div>
          {caption ? <div className="message-body__text">{renderTextSegments(caption)}</div> : null}
        </div>
      );
    }

    const src = mediaUrl(attachmentUrl);
    return (
      <div className="message-body">
        <button
          type="button"
          className="message-body__image-btn"
          onClick={() => setLightboxSrc(src)}
        >
          <img src={src} alt="" className="message-body__image" />
        </button>
        {caption ? <div className="message-body__text">{renderTextSegments(caption)}</div> : null}
        {lightboxSrc && (
          <ImageLightbox src={lightboxSrc} onClose={() => setLightboxSrc(null)} />
        )}
      </div>
    );
  }

  return (
    <div className="message-body">
      <div className="message-body__text">{renderTextSegments(body || '')}</div>
    </div>
  );
}
