# QR Code Generator API

Backend API for generating QR codes.

## Supported QR Types
- URL
- Text
- WiFi
- Phone
- SMS
- Email

## Deploy to Railway

1. Push this folder to GitHub
2. Go to [railway.app](https://railway.app)
3. New Project → Deploy from GitHub
4. Select this repo
5. Done! Get your URL from the deployment

## API Endpoint

`POST /api/generate`

```json
{
  "type": "wifi",
  "data": {
    "ssid": "MyNetwork",
    "password": "secret123",
    "encryption": "WPA"
  }
}
```

## Local Development

```bash
npm install
npm start
```
