const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');

function createMessageUpload(getDestParts) {
  const storage = multer.diskStorage({
    destination: (req, _file, cb) => {
      const { businessId, threadId } = getDestParts(req);
      const dir = path.join(process.env.UPLOAD_DIR || './uploads', businessId, 'messages', threadId);
      fs.mkdirSync(dir, { recursive: true });
      cb(null, dir);
    },
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
      cb(null, `${uuidv4()}${ext}`);
    },
  });

  return multer({
    storage,
    limits: { fileSize: 8 * 1024 * 1024 },
    fileFilter: (_req, file, cb) => {
      const mimeOk = /^image\/(jpeg|jpg|png|webp|gif|heic|heif)$/i.test(file.mimetype);
      const extOk = /\.(jpe?g|png|webp|gif|heic|heif)$/i.test(file.originalname || '');
      if (mimeOk || (file.mimetype === 'application/octet-stream' && extOk)) {
        cb(null, true);
      } else {
        cb(new Error('Μόνο εικόνες επιτρέπονται (JPEG, PNG, WebP, GIF)'));
      }
    },
  });
}

function handleMessageUpload(upload) {
  return (req, res, next) => {
    upload.single('image')(req, res, (err) => {
      if (err) {
        const status = err.code === 'LIMIT_FILE_SIZE' ? 413 : 400;
        return res.status(status).json({ error: err.message || 'Αποτυχία αποστολής εικόνας' });
      }
      next();
    });
  };
}

function publicUploadPath(businessId, threadId, filename) {
  return `/uploads/${businessId}/messages/${threadId}/${filename}`;
}

function saveMessageImageBuffer(businessId, threadId, buffer, ext = '.jpg') {
  const dir = path.join(process.env.UPLOAD_DIR || './uploads', businessId, 'messages', threadId);
  fs.mkdirSync(dir, { recursive: true });
  const filename = `${uuidv4()}${ext}`;
  fs.writeFileSync(path.join(dir, filename), buffer);
  return publicUploadPath(businessId, threadId, filename);
}

function parseBase64Image(input) {
  if (!input) return null;
  const raw = String(input).replace(/^data:image\/[a-z0-9+.-]+;base64,/i, '').trim();
  if (!raw) return null;
  const buf = Buffer.from(raw, 'base64');
  if (!buf.length) return null;
  return buf;
}

function validateAttachmentUrl(businessId, threadId, url) {
  if (!url) return null;
  const expected = `/uploads/${businessId}/messages/${threadId}/`;
  if (!String(url).startsWith(expected)) {
    throw Object.assign(new Error('Μη έγκυρο συνημμένο'), { status: 400 });
  }
  return url;
}

module.exports = {
  createMessageUpload,
  handleMessageUpload,
  publicUploadPath,
  validateAttachmentUrl,
  saveMessageImageBuffer,
  parseBase64Image,
};
