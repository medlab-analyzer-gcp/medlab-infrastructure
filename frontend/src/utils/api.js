// API utility functions for calling GCP Cloud Run services
import gcpConfig from '../gcp-config';

// All requests go through API Gateway
const REPORT_SERVICE_URL = gcpConfig.api.gatewayUrl;
const ANALYSIS_SERVICE_URL = gcpConfig.api.gatewayUrl;

export const WS_SERVICE_URL = gcpConfig.api.wsServiceUrl;

/**
 * Upload a report file
 */
export async function uploadReport(jwtToken, userId, fileName, fileType, fileContent) {
  const response = await fetch(`${REPORT_SERVICE_URL}/reports`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${jwtToken}`
    },
    body: JSON.stringify({
      userId,
      fileName,
      fileType,
      fileContent
    })
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'Failed to upload report');
  }

  return response.json();
}

/**
 * Get all reports for a user
 */
export async function getReports(jwtToken, userId) {
  const response = await fetch(`${REPORT_SERVICE_URL}/reports?userId=${userId}`, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${jwtToken}`
    }
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'Failed to fetch reports');
  }

  return response.json();
}

/**
 * Get a single report
 */
export async function getReport(jwtToken, reportId) {
  const response = await fetch(`${REPORT_SERVICE_URL}/reports/${reportId}`, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${jwtToken}`
    }
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'Failed to fetch report');
  }

  return response.json();
}

/**
 * Delete a report
 */
export async function deleteReport(jwtToken, reportId) {
  const response = await fetch(`${REPORT_SERVICE_URL}/reports/${reportId}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${jwtToken}`
    }
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'Failed to delete report');
  }

  return response.json();
}

/**
 * Get file URL for a report
 */
export async function getFileUrl(jwtToken, reportId) {
  const response = await fetch(`${REPORT_SERVICE_URL}/reports/${reportId}/file-url`, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${jwtToken}`
    }
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'Failed to get file URL');
  }

  return response.json();
}

/**
 * Analyze test results
 */
export async function analyzeResults(jwtToken, reportId, userId, testResults, patientInfo) {
  const response = await fetch(`${ANALYSIS_SERVICE_URL}/analyze`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${jwtToken}`
    },
    body: JSON.stringify({
      reportId,
      userId,
      testResults,
      patientInfo
    })
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'Failed to analyze results');
  }

  return response.json();
}

/**
 * Get analysis by ID
 */
export async function getAnalysis(jwtToken, analysisId) {
  const response = await fetch(`${ANALYSIS_SERVICE_URL}/analyze/${analysisId}`, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${jwtToken}`
    }
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'Failed to fetch analysis');
  }

  return response.json();
}

/**
 * Get latest analysis for a report
 */
export async function getAnalysisByReportId(jwtToken, reportId) {
  const response = await fetch(`${ANALYSIS_SERVICE_URL}/analyze/report/${reportId}`, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${jwtToken}`
    }
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'Failed to fetch analysis');
  }

  return response.json();
}

/**
 * Queue analysis request via Pub/Sub (event-driven)
 */
export async function analyzeRequest(jwtToken, reportId, userId, testResults, patientInfo) {
  const response = await fetch(`${REPORT_SERVICE_URL}/analyze-request`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${jwtToken}`
    },
    body: JSON.stringify({ reportId, userId, testResults, patientInfo })
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'Failed to queue analysis');
  }

  return response.json();
}
