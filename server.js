const express = require('express');
const cors = require('cors');
const QRCode = require('qrcode');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// URL validation helper
const isValidUrl = (string) => {
  try {
    new URL(string);
    return true;
  } catch (_) {
    return false;
  }
};

// Format WiFi QR code string
const formatWifiString = (ssid, password, encryption) => {
  // WiFi QR format: WIFI:T:<encryption>;S:<ssid>;P:<password>;;
  const enc = encryption || 'WPA';
  return `WIFI:T:${enc};S:${ssid};P:${password};;`;
};

// Format Phone QR code string
const formatPhoneString = (phone) => {
  return `tel:${phone}`;
};

// Format SMS QR code string
const formatSmsString = (phone, message) => {
  if (message) {
    return `smsto:${phone}:${message}`;
  }
  return `smsto:${phone}`;
};

// Format Email QR code string
const formatEmailString = (email, subject, body) => {
  let mailto = `mailto:${email}`;
  const params = [];
  if (subject) params.push(`subject=${encodeURIComponent(subject)}`);
  if (body) params.push(`body=${encodeURIComponent(body)}`);
  if (params.length > 0) {
    mailto += '?' + params.join('&');
  }
  return mailto;
};

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'QR Code API is running' });
});

// Generate QR code endpoint - supports multiple types
app.post('/api/generate', async (req, res) => {
  try {
    const { type, data } = req.body;

    let qrContent = '';

    switch (type) {
      case 'url':
        if (!data.url) {
          return res.status(400).json({ success: false, error: 'URL is required' });
        }
        // Auto-add https if missing
        let url = data.url;
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          url = 'https://' + url;
        }
        if (!isValidUrl(url)) {
          return res.status(400).json({ success: false, error: 'Invalid URL format' });
        }
        qrContent = url;
        break;

      case 'text':
        if (!data.text) {
          return res.status(400).json({ success: false, error: 'Text is required' });
        }
        qrContent = data.text;
        break;

      case 'wifi':
        if (!data.ssid) {
          return res.status(400).json({ success: false, error: 'WiFi network name (SSID) is required' });
        }
        qrContent = formatWifiString(data.ssid, data.password || '', data.encryption || 'WPA');
        break;

      case 'phone':
        if (!data.phone) {
          return res.status(400).json({ success: false, error: 'Phone number is required' });
        }
        qrContent = formatPhoneString(data.phone);
        break;

      case 'sms':
        if (!data.phone) {
          return res.status(400).json({ success: false, error: 'Phone number is required' });
        }
        qrContent = formatSmsString(data.phone, data.message || '');
        break;

      case 'email':
        if (!data.email) {
          return res.status(400).json({ success: false, error: 'Email address is required' });
        }
        qrContent = formatEmailString(data.email, data.subject || '', data.body || '');
        break;

      default:
        // Legacy support - if 'url' field exists in body directly
        if (req.body.url) {
          let legacyUrl = req.body.url;
          if (!legacyUrl.startsWith('http://') && !legacyUrl.startsWith('https://')) {
            legacyUrl = 'https://' + legacyUrl;
          }
          qrContent = legacyUrl;
        } else {
          return res.status(400).json({ success: false, error: 'Invalid QR type. Use: url, text, wifi, phone, sms, email' });
        }
    }

    // Generate QR code as base64 data URL
    const qrCodeDataUrl = await QRCode.toDataURL(qrContent, {
      width: 400,
      margin: 2,
      color: {
        dark: '#000000',
        light: '#ffffff'
      },
      errorCorrectionLevel: 'H'
    });

    res.json({
      success: true,
      type: type || 'url',
      content: qrContent,
      qrCode: qrCodeDataUrl
    });

  } catch (error) {
    console.error('QR generation error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to generate QR code'
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 QR Code API running on http://localhost:${PORT}`);
  console.log(`📡 Health check: http://localhost:${PORT}/api/health`);
  console.log(`🔲 Generate QR: POST http://localhost:${PORT}/api/generate`);
  console.log(`📱 Supported types: url, text, wifi, phone, sms, email`);
});
