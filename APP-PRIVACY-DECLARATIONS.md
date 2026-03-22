# FreePace — App Store Connect App Privacy Declarations

Use these answers when filling out the App Privacy section in App Store Connect.

---

## "Does your app collect data?"

**Yes**

---

## Data Types Collected

### 1. Precise Location

| Question | Answer |
|----------|--------|
| Is this data collected? | **Yes** |
| Is this data linked to the user's identity? | **No** |
| Is this data used for tracking? | **No** |
| Purpose | **App Functionality** |

Notes: Precise GPS location is used to track running routes, calculate distance, pace, and elevation. Data is stored locally on device only.

### 2. Fitness & Exercise

| Question | Answer |
|----------|--------|
| Is this data collected? | **Yes** |
| Is this data linked to the user's identity? | **No** |
| Is this data used for tracking? | **No** |
| Purpose | **App Functionality** |

Notes: Step count and cadence data from the device pedometer are used to display steps per minute during runs. Data is stored locally on device only.

---

## Data Types NOT Collected

All other categories should be marked as **"Not collected"**:

- Contact Info (name, email, phone, address)
- Health & Fitness (other than exercise data above)
- Financial Info
- Contacts
- User Content
- Browsing History
- Search History
- Identifiers (user ID, device ID)
- Usage Data (product interaction, advertising data)
- Diagnostics (crash data, performance data)
- Purchases
- Sensitive Info
- Other Data

---

## Additional Notes

- The app does **not** use any third-party analytics or advertising SDKs
- The app does **not** create user accounts
- The app does **not** transmit any data to external servers (except Apple WeatherKit API calls for weather conditions, which are handled by Apple)
- All user-generated data (runs, routes, splits) is stored exclusively on the local device
