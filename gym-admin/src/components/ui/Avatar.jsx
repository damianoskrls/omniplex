import { hashColor, initials, mediaUrl } from '../../utils/media';

export default function Avatar({ name, image, color, size = 44, round = true }) {
  const dim = size;
  const radius = round ? '50%' : 12;
  const src = mediaUrl(image);
  const accent = color || hashColor(name);

  if (src) {
    return (
      <img
        src={src}
        alt={name || ''}
        style={{
          width: dim,
          height: dim,
          borderRadius: radius,
          objectFit: 'cover',
          flexShrink: 0,
          border: `2px solid ${accent}33`,
        }}
      />
    );
  }

  return (
    <div
      style={{
        width: dim,
        height: dim,
        borderRadius: radius,
        flexShrink: 0,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: `linear-gradient(135deg, ${accent}, ${hashColor(name, 45, 35)})`,
        color: '#fff',
        fontWeight: 800,
        fontSize: size * 0.36,
      }}
    >
      {initials(name)}
    </div>
  );
}
