# 🚨 Railway Deployment Troubleshooting Guide

## Common Issues and Solutions

### Issue 1: Build Fails - Module Not Found

**Symptoms:**
- Build error: "Cannot find module"
- npm install fails

**Solution:**
Check that all dependencies are in `package.json`:
```bash
cd backend
npm install  # Should complete without errors
```

### Issue 2: Server Crashes on Start

**Symptoms:**
- Build succeeds but server exits immediately
- "Application failed" error in Railway logs

**Solution:**
The server now has a root endpoint and proper error handling. Check logs for:
- Missing environment variables
- Database connection errors
- Port binding issues

### Issue 3: Environment Variables Not Set

**Symptoms:**
- Server starts but API calls fail
- Database connection errors

**Solution:**
1. Go to Railway dashboard → Variables tab
2. Add ALL variables from `RAILWAY_ENV_VARS.txt`
3. Make sure `NODE_ENV=production`
4. Check for typos in variable names

### Issue 4: Database Connection Timeout

**Symptoms:**
- MongoDB connection timeout errors
- "MongoNetworkError"

**Solution:**
1. Check MongoDB Atlas whitelist allows all IPs: `0.0.0.0/0`
2. Verify connection string is correct
3. Test connection locally first

### Issue 5: Port Configuration

**Symptoms:**
- Railway can't connect to your app
- "Application failed to respond"

**Solution:**
Railway automatically sets `PORT` environment variable. Your server listens on:
```javascript
const PORT = process.env.PORT || 3001;
```
This is correct! Railway will use their assigned port.

### Issue 6: CORS Errors

**Symptoms:**
- Requests from iOS app fail
- CORS errors in browser console

**Solution:**
CORS has been updated to allow all origins in production:
```javascript
origin: [
  'http://localhost:3000',
  'http://192.168.1.72:3000',
  'http://127.0.0.1:3000',
  // Allows all in production
  ...(process.env.NODE_ENV === 'production' ? [true] : [])
]
```

## How to Debug Railway Deployments

### 1. Check Build Logs
1. Go to Railway dashboard
2. Click on your deployment
3. Check "Logs" tab
4. Look for error messages

### 2. Test Locally First
```bash
cd backend
NODE_ENV=production PORT=3001 npm start
```

Should start without errors!

### 3. Check Health Endpoint
After deployment, test:
```bash
curl https://your-app.railway.app/api/health
```

Should return:
```json
{"status":"OK","message":"YUGI API is running","timestamp":"..."}
```

### 4. View Real-Time Logs
Railway provides streaming logs:
1. Go to Railway dashboard
2. Click your service
3. Click "Logs" tab
4. Watch for startup messages

### 5. Common Error Messages

**"Application failed to respond"**
- Server crashed on startup
- Check logs for errors
- Verify environment variables are set

**"Build failed"**
- npm install failed
- Missing dependency
- Node version mismatch

**"MongoNetworkError"**
- Database connection issue
- Check MongoDB whitelist
- Verify MONGODB_URI

## Railway-Specific Configurations Fixed

### ✅ nixpacks.toml
```toml
[phases.setup]
nixPkgs = ['nodejs-18_x', 'npm']  # Explicit Node 18
```

### ✅ CORS Configuration
```javascript
// Now allows all origins in production
```

### ✅ Root Endpoint
```javascript
app.get('/', (req, res) => {
  res.json({ message: 'YUGI API Server', status: 'running' });
});
```

### ✅ Health Check
```javascript
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'YUGI API is running' });
});
```

## Step-by-Step Debugging Process

### Step 1: Verify Local Build
```bash
cd backend
rm -rf node_modules package-lock.json
npm install
npm start
```

### Step 2: Test Production Mode
```bash
NODE_ENV=production npm start
```

### Step 3: Check Railway Deployment
1. Push changes to GitHub
2. Watch Railway deployment logs
3. Check for build/startup errors

### Step 4: Verify Environment Variables
1. Railway dashboard → Variables
2. Compare with `RAILWAY_ENV_VARS.txt`
3. Make sure all required vars are set

### Step 5: Test Endpoints
```bash
# Health check
curl https://your-app.railway.app/api/health

# Root endpoint
curl https://your-app.railway.app/
```

## Still Having Issues?

### Check These:
1. ✅ All files committed and pushed to GitHub
2. ✅ Root directory set to `backend/` in Railway
3. ✅ Environment variables copied correctly
4. ✅ MongoDB Atlas whitelist allows all IPs
5. ✅ `NODE_ENV=production` set in Railway

### Get More Help:
1. Check Railway documentation: https://docs.railway.app
2. Join Railway Discord: https://discord.gg/railway
3. Review deployment logs in Railway dashboard
4. Test endpoints with curl

## Quick Fix Checklist

Run through this before deploying:

- [ ] `npm install` works locally without errors
- [ ] `npm start` starts server successfully
- [ ] Local health check works: `curl http://localhost:3001/api/health`
- [ ] All environment variables ready in `RAILWAY_ENV_VARS.txt`
- [ ] MongoDB connection string verified
- [ ] Changes committed and pushed to GitHub
- [ ] Railway root directory set to `backend/`
- [ ] Ready to redeploy!

---

**Your app should now deploy successfully! 🚂**

