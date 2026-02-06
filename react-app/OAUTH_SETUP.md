# Google OAuth Setup Guide

Complete guide to setting up Google OAuth authentication for the React app.

---

## 📋 Prerequisites

- Google Account
- Access to [Google Cloud Console](https://console.cloud.google.com/)
- Node.js and npm installed

---

## 🚀 Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click on the project dropdown at the top
3. Click "New Project"
4. Enter project name (e.g., "My App")
5. Click "Create"
6. Wait for the project to be created, then select it

---

## 🔑 Step 2: Enable Google+ API

1. In the Google Cloud Console, navigate to **APIs & Services > Library**
2. Search for "Google+ API"
3. Click on it and press "Enable"
4. Wait for the API to be enabled

---

## 🛠️ Step 3: Configure OAuth Consent Screen

1. Go to **APIs & Services > OAuth consent screen**
2. Select **External** user type (unless you have a Google Workspace account)
3. Click "Create"

### Fill in the App Information:

**Required Fields:**

- **App name:** My App (or your preferred name)
- **User support email:** Your email address
- **Developer contact information:** Your email address

**Optional Fields:**

- **App logo:** Upload your logo (optional)
- **Application home page:** http://localhost:3000
- **Application privacy policy link:** (optional for development)
- **Application terms of service link:** (optional for development)

4. Click "Save and Continue"

### Scopes Section:

5. Click "Add or Remove Scopes"
6. Add the following scopes:
   - `email`
   - `profile`
   - `openid`
7. Click "Update" then "Save and Continue"

### Test Users (for development):

8. Add your email address as a test user
9. Click "Save and Continue"
10. Review the summary and click "Back to Dashboard"

---

## 🔐 Step 4: Create OAuth 2.0 Credentials

1. Go to **APIs & Services > Credentials**
2. Click "Create Credentials" at the top
3. Select "OAuth client ID"
4. Choose "Web application" as the application type

### Configure the OAuth Client:

**Name:** React App

**Authorized JavaScript origins:**

```
http://localhost:3000
http://localhost
```

**Authorized redirect URIs:**

```
http://localhost:3000
http://localhost:3000/
```

5. Click "Create"
6. A popup will show your **Client ID** and **Client Secret**
7. **Copy the Client ID** - you'll need this for your app
8. Click "OK"

---

## ⚙️ Step 5: Configure Your React App

### 1. Create .env File

In the `react-app` directory, create a `.env` file:

```bash
cd react-app
cp .env.example .env
```

### 2. Add Your Client ID

Edit the `.env` file and add your Google Client ID:

```env
REACT_APP_GOOGLE_CLIENT_ID=your_actual_client_id_here.apps.googleusercontent.com
```

**Example:**

```env
REACT_APP_GOOGLE_CLIENT_ID=123456789-abcdefghijklmnop.apps.googleusercontent.com
```

### 3. Install Dependencies

```bash
npm install
```

---

## 🧪 Step 6: Test Your Application

### 1. Start the Development Server

```bash
npm start
```

The app should open at `http://localhost:3000`

### 2. Test Google Login

1. Click the "Sign in with Google" button
2. Select your Google account
3. Grant permissions when prompted
4. You should be redirected to the Dashboard

### 3. Test Protected Routes

Try accessing:

- Dashboard: `http://localhost:3000/dashboard` (requires login)
- Settings: `http://localhost:3000/settings` (requires login)
- Home: `http://localhost:3000/` (public)

---

## 🐛 Troubleshooting

### Issue: "Error 400: redirect_uri_mismatch"

**Solution:**

- Verify that `http://localhost:3000` is in your **Authorized JavaScript origins**
- Verify that `http://localhost:3000/` is in your **Authorized redirect URIs**
- Make sure there are no extra spaces
- Wait a few minutes for changes to propagate

### Issue: "Access blocked: Authorization Error"

**Solution:**

- Make sure your email is added as a test user in the OAuth consent screen
- Verify your app is in "Testing" mode (not "Production")
- Check that you've enabled the Google+ API

### Issue: "idpiframe_initialization_failed"

**Solution:**

- Clear your browser cookies for localhost
- Try incognito/private mode
- Verify your Client ID is correct in the `.env` file

### Issue: Client ID not loading

**Solution:**

- Make sure `.env` file is in the `react-app` directory
- Variable name must be `REACT_APP_GOOGLE_CLIENT_ID`
- Restart the development server after changing `.env`

---

## 🔒 Security Best Practices

### For Development:

✅ Keep `.env` file in `.gitignore`
✅ Use http://localhost for testing
✅ Add only trusted test users

### For Production:

✅ Use HTTPS only
✅ Update **Authorized JavaScript origins** to your production domain
✅ Update **Authorized redirect URIs** to your production domain
✅ Move OAuth consent screen from "Testing" to "Production"
✅ Never commit Client ID or Client Secret to version control
✅ Use environment variables on your hosting platform

---

## 📚 Additional Resources

- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [React OAuth Google Library](https://www.npmjs.com/package/@react-oauth/google)
- [Google Cloud Console](https://console.cloud.google.com/)

---

## ✅ Verification Checklist

Before going live, verify:

- [ ] OAuth consent screen is configured
- [ ] Google+ API is enabled
- [ ] Client ID is created
- [ ] Authorized origins include your domain
- [ ] Authorized redirect URIs include your domain
- [ ] `.env` file has correct Client ID
- [ ] Test users can successfully log in
- [ ] Protected routes work correctly
- [ ] Logout functionality works
- [ ] User data persists in localStorage

---

## 🎉 Success!

If you've completed all steps and can log in with Google, your OAuth setup is complete!

Your app now has:

- ✅ Secure Google authentication
- ✅ Protected routes
- ✅ User session management
- ✅ Profile information access
