// GCP Firebase Configuration
export const gcpConfig = {
  // Firebase Config - Replace with your Firebase project credentials
  // Or use environment variables (recommended)
  firebase: {
    apiKey: import.meta.env.VITE_FIREBASE_API_KEY || "YOUR_FIREBASE_API_KEY",
    authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || "YOUR_PROJECT_ID.firebaseapp.com",
    projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || "YOUR_PROJECT_ID",
    storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || "YOUR_PROJECT_ID.appspot.com",
    messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || "YOUR_MESSAGING_SENDER_ID",
    appId: import.meta.env.VITE_FIREBASE_APP_ID || "YOUR_APP_ID"
  },
  
  // API Gateway - single entry point for all backend services
  api: {
    gatewayUrl: import.meta.env.VITE_API_GATEWAY_URL || "",
    wsServiceUrl: import.meta.env.VITE_WS_SERVICE_URL || "",
  },
  
  // Environment
  region: import.meta.env.VITE_REGION || "us-central1",
  environment: import.meta.env.VITE_ENV || "dev"
};

export default gcpConfig;
