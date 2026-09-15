import { useEffect } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';

export default function ImageLightbox({ src, alt = '', onClose }) {
  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'Escape') onClose();
    };
    document.body.style.overflow = 'hidden';
    window.addEventListener('keydown', onKey);
    return () => {
      document.body.style.overflow = '';
      window.removeEventListener('keydown', onKey);
    };
  }, [onClose]);

  if (!src) return null;

  return createPortal(
    <div className="image-lightbox" onClick={onClose} role="dialog" aria-modal="true">
      <button type="button" className="image-lightbox__close" onClick={onClose} aria-label="Κλείσιμο">
        <X size={22} />
      </button>
      <img
        src={src}
        alt={alt}
        className="image-lightbox__img"
        onClick={(e) => e.stopPropagation()}
      />
    </div>,
    document.body,
  );
}
