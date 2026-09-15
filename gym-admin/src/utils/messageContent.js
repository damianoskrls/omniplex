const URL_REGEX = /(https?:\/\/[^\s<]+[^\s<.,;:!?)\]}'"])/gi;
const YOUTUBE_REGEX = /(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/i;

export function extractYouTubeId(url) {
  const match = String(url).match(YOUTUBE_REGEX);
  return match?.[1] || null;
}

export function splitMessageSegments(text) {
  const input = String(text || '');
  if (!input) return [];

  const segments = [];
  let lastIndex = 0;
  const regex = new RegExp(URL_REGEX.source, 'gi');
  let match;

  while ((match = regex.exec(input)) !== null) {
    if (match.index > lastIndex) {
      segments.push({ type: 'text', value: input.slice(lastIndex, match.index) });
    }
    const url = match[0];
    const videoId = extractYouTubeId(url);
    segments.push(videoId ? { type: 'youtube', value: url, videoId } : { type: 'link', value: url });
    lastIndex = match.index + url.length;
  }

  if (lastIndex < input.length) {
    segments.push({ type: 'text', value: input.slice(lastIndex) });
  }

  return segments.length ? segments : [{ type: 'text', value: input }];
}

export const COMMON_EMOJIS = [
  '😀', '😂', '😊', '😍', '🥰', '😎', '🤔', '😅', '🙏', '👍',
  '👏', '💪', '🔥', '✅', '❤️', '🎉', '⭐', '💯', '🏋️', '🥗',
  '📅', '📷', '💬', '👋', '🙂', '😢', '😡', '🤝', '✨', '🚀',
];
