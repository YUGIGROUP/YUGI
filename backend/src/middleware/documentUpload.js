const multer = require('multer');

// Store in memory — files are small (max 10MB), and we hand off to S3 immediately.
const storage = multer.memoryStorage();

const ALLOWED_MIME_TYPES = [
  'application/pdf',
  'image/png',
  'image/jpeg',
  'image/jpg',
];

const MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024; // 10MB

const fileFilter = (req, file, cb) => {
  if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    return cb(new Error(`Invalid file type. Allowed: PDF, PNG, JPG. Got: ${file.mimetype}`), false);
  }
  cb(null, true);
};

const documentUpload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: MAX_FILE_SIZE_BYTES,
  },
});

module.exports = documentUpload;
