# Google Places API Backend Error Investigation

## Problem
Backend is failing with error: `Cannot read properties of undefined (reading 'name')` when trying to fetch venue data from Google Places API.

## Current Status
- ✅ iOS app works perfectly - calls Google Places directly
- ❌ Backend API fails - shows default/fallback data instead of real data

## Impact
When users browse/search for classes, they see generic venue information instead of detailed, accurate data with transit stations.

## What We've Done

### 1. Enhanced Error Handling
- Added comprehensive defensive checks before accessing any properties
- Wrapped all property access in try-catch blocks
- Added validation for API key format
- Added checks for response structure at every step

### 2. Comprehensive Logging
- Logs full API response structure
- Logs response data (truncated if too large)
- Logs object structures when errors occur
- Logs API key validation status
- Logs request URLs (with key hidden)

### 3. Created Test Script
Created `test-google-places-direct.js` to test the API directly and see exactly what's being returned.

## Next Steps

### Step 1: Run the Test Script
```bash
cd backend
node test-google-places-direct.js
```

This will:
- Test the Google Places API directly
- Show the exact response structure
- Identify where the error is occurring
- Verify API key is working

### Step 2: Check Railway Logs
After restarting the Railway server and testing with "Polka Theatre", check logs for:
- `🔍 Google Places API full response:` - Shows what Google Places is actually returning
- `🔍 Google Places Details API full response:` - Shows the details response
- `❌ Error building Google Places return object:` - Shows where the error occurs
- `source: 'default'` vs `source: 'google'` - Shows if real or default data

### Step 3: Fix Based on Findings
Once we see the actual API response structure, we can:
- Fix the property access issue
- Ensure all edge cases are handled
- Verify the data structure matches expectations

## Code Locations

### Main Function
- `backend/src/services/venueDataService.js` - `getGooglePlacesData()` method (line ~97)

### Where It's Called
- `backend/src/routes/classes.js` - `transformClassForIOS()` function (line ~93)
- `backend/src/routes/classes.js` - `/venues/analyze` endpoint (line ~709)

### Test Script
- `backend/test-google-places-direct.js` - Direct API test

## Expected Behavior

### When Working
1. Backend calls Google Places Text Search API
2. Gets place_id from first result
3. Calls Google Places Details API with place_id
4. Extracts venue information (parking, baby changing, accessibility)
5. Finds nearby transit stations
6. Returns enriched data with `source: 'google'`

### When Failing
1. Backend tries Google Places API
2. Error occurs (currently "Cannot read properties of undefined (reading 'name')")
3. Falls back to default data
4. Returns generic data with `source: 'default'`

## Debugging Checklist

- [ ] Run test script to verify API key works
- [ ] Check Railway logs for full API response
- [ ] Verify API key format (should start with "AIza")
- [ ] Check if error occurs in search or details API call
- [ ] Verify response structure matches expectations
- [ ] Test with different venues to see if issue is venue-specific

