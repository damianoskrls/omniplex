const { S3Client } = require('@aws-sdk/client-s3');
const { Upload } = require('@aws-sdk/lib-storage');
const multer = require('multer');
const path = require('path');

const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID;
const R2_ACCESS_KEY = process.env.R2_ACCESS_KEY;
const R2_SECRET_KEY = process.env.R2_SECRET_KEY;
const R2_BUCKET = process.env.R2_BUCKET || 'omniplex';
const R2_PUBLIC_URL = process.env.R2_PUBLIC_URL || 'https://pub-48c284e5304e457ea2182157948d7efe.r2.dev';

function getS3Client() {
  return new S3Client({
    region: 'auto',
    endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: R2_ACCESS_KEY,
      secretAccessKey: R2_SECRET_KEY,
    },
  });
}

// Returns a multer middleware that uploads directly to R2
// keyFn(req, file) => string (the R2 object key, e.g. "uploads/business-id/staff/photo.jpg")
function r2Multer({ keyFn, allowedMimes, maxSizeMb = 10 }) {
  const storage = {
    _handleFile(req, file, cb) {
      const key = keyFn(req, file);
      const client = getS3Client();
      const upload = new Upload({
        client,
        params: {
          Bucket: R2_BUCKET,
          Key: key,
          Body: file.stream,
          ContentType: file.mimetype,
        },
      });
      upload.done()
        .then(() => {
          file.key = key;
          file.publicUrl = `${R2_PUBLIC_URL}/${key}`;
          cb(null, { key, publicUrl: file.publicUrl });
        })
        .catch(cb);
    },
    _removeFile(req, file, cb) { cb(null); },
  };

  return multer({
    storage,
    limits: { fileSize: maxSizeMb * 1024 * 1024 },
    fileFilter: allowedMimes
      ? (req, file, cb) => cb(null, allowedMimes.includes(file.mimetype))
      : undefined,
  });
}

// Upload a buffer directly to R2, returns public URL
async function uploadBuffer({ buffer, key, contentType }) {
  const client = getS3Client();
  const upload = new Upload({
    client,
    params: { Bucket: R2_BUCKET, Key: key, Body: buffer, ContentType: contentType },
  });
  await upload.done();
  return `${R2_PUBLIC_URL}/${key}`;
}

function publicUrl(key) {
  return `${R2_PUBLIC_URL}/${key}`;
}

// Whether R2 is configured
function isConfigured() {
  return !!(R2_ACCOUNT_ID && R2_ACCESS_KEY && R2_SECRET_KEY);
}

module.exports = { r2Multer, uploadBuffer, publicUrl, isConfigured, R2_PUBLIC_URL };
