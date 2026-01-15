# InvoiceBot

An AI-powered invoice extraction system that syncs emails from Gmail, detects invoices in PDF attachments, and extracts key data (vendor, amount, dates) using LLMs.

![Screenshot](screenshot.png)

## Requirements

- Ruby 3.4.5
- Node.js
- qpdf (for PDF processing)

## Setup

1. **Install dependencies**

   ```bash
   bundle install
   npm install
   ```

2. **Configure environment variables**

   ```bash
   cp .env.example .env
   ```

   Edit `.env` and add:
   - `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` - Create OAuth credentials in [Google Cloud Console](https://console.cloud.google.com/apis/credentials) with Gmail API enabled
   - `OPENAI_API_KEY` - For invoice detection and extraction

3. **Setup database**

   ```bash
   bin/rails db:setup
   ```

4. **Run the app**

   ```bash
   bin/dev
   ```

   Visit http://localhost:3000

## Usage

1. Sign in with Google to connect your Gmail account
2. The app syncs emails with PDF attachments from the last 30 days
3. Background jobs detect invoices and extract data automatically
