// Firebase initialization and configuration
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import gcpConfig from './gcp-config';

// Initialize Firebase
const firebaseApp = initializeApp(gcpConfig.firebase);

// Initialize Firebase Auth
export const auth = getAuth(firebaseApp);

// Export API URLs for services
export const API_URLS = {
  reportService: gcpConfig.api.reportServiceUrl,
  analysisService: gcpConfig.api.analysisServiceUrl
};

export default firebaseApp;
