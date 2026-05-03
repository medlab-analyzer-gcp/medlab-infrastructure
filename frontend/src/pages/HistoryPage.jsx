import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { getReports, getFileUrl, deleteReport, getAnalysis } from "../utils/api";
import { getSocket, clearSocket } from "../utils/socketManager";

function HistoryPage({ jwtToken, user }) {
  const navigate = useNavigate();
  const [reports, setReports] = useState([]);
  const [selectedReport, setSelectedReport] = useState(null);
  const [selectedAnalysis, setSelectedAnalysis] = useState(null);
  const [analysisLoading, setAnalysisLoading] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!jwtToken || !user) return;
    fetchReports();
  }, [jwtToken, user]);

  // WebSocket — only active when coming from AnalyzePage after submitting
  useEffect(() => {
    const socket = getSocket();
    if (!socket) return;

    // Immediately fetch reports — analysis may have already completed
    // before this component mounted (analysis is very fast)
    fetchReports();

    // Also listen for push in case analysis is still in progress
    socket.on("analysis-done", () => {
      fetchReports();
      clearSocket();
    });

    // If no push within 10 seconds, fetch once more and close socket
    const fallback = setTimeout(() => {
      fetchReports();
      clearSocket();
    }, 10000);

    return () => {
      clearTimeout(fallback);
      clearSocket();
    };
  }, []);

  const fetchReports = async () => {
    setLoading(true);
    setError("");

    try {
      const data = await getReports(jwtToken, user.userId);
      setReports(data.reports || []);
    } catch (err) {
      setError(err.message || "Failed to load reports");
    } finally {
      setLoading(false);
    }
  };

  const handleViewFile = async (report) => {
    try {
      const data = await getFileUrl(jwtToken, report.reportId);
      window.open(data.url, "_blank");
    } catch (err) {
      setError(err.message || "Failed to load file");
    }
  };

  const handleViewResults = async (report) => {
    setSelectedReport(report);
    setSelectedAnalysis(null);
    setAnalysisLoading(true);
    try {
      const data = await getAnalysis(jwtToken, report.analysisId);
      setSelectedAnalysis(data.analysis?.testResults || data.testResults || []);
    } catch (err) {
      setSelectedAnalysis([]);
      setError(err.message || "Failed to load analysis results");
    } finally {
      setAnalysisLoading(false);
    }
  };

  const handleDelete = async (reportId) => {
    if (!confirm("Are you sure you want to delete this report?")) {
      return;
    }

    try {
      await deleteReport(jwtToken, reportId);
      fetchReports();
    } catch (err) {
      setError(err.message || "Failed to delete report");
    }
  };

  return (
    <section className="history-page">
      <div className="page-intro">
        <p className="eyebrow">History</p>
        <h1>Your Uploaded Reports</h1>
        <p>View all your uploaded medical lab reports.</p>
      </div>

      {loading && <p>Loading reports...</p>}
      {error && <p className="error-message">{error}</p>}

      {!loading && !error && reports.length === 0 && (
        <p>
          No reports uploaded yet. Go to Upload page to add your first report!
        </p>
      )}

      {!loading && !error && reports.length > 0 && (
        <table className="reports-table">
          <thead>
            <tr>
              <th>File Name</th>
              <th>Upload Date</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {reports.map((report) => (
              <tr key={report.reportId}>
                <td>
                  <button
                    onClick={() => handleViewFile(report)}
                    className="file-link"
                  >
                    {report.fileName}
                  </button>
                </td>
                <td>{report.uploadedAt ? new Date(report.uploadedAt).toLocaleDateString() : "—"}</td>
                <td>
                  <span
                    className={`status-badge status-${report.status?.toLowerCase()}`}
                  >
                    {report.status}
                  </span>
                </td>
                <td>
                  <div className="action-buttons">
                    {report.status?.toLowerCase() === "uploaded" && (
                      <button
                        onClick={() =>
                          navigate(`/analyze?reportId=${report.reportId}`)
                        }
                        className="btn-analyze"
                      >
                        Analyze
                      </button>
                    )}
                    {report.status?.toLowerCase() === "analyzed" && (
                      <button
                        onClick={() => handleViewResults(report)}
                        className="btn-view"
                      >
                        View Results
                      </button>
                    )}
                    <button
                      onClick={() => handleDelete(report.reportId)}
                      className="btn-delete"
                    >
                      Delete
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {selectedReport && (
        <div
          className="results-modal"
          onClick={() => {
            setSelectedReport(null);
            setSelectedAnalysis(null);
          }}
        >
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Analysis Results: {selectedReport.fileName}</h2>
              <button
                onClick={() => {
                  setSelectedReport(null);
                  setSelectedAnalysis(null);
                }}
                className="btn-close"
              >
                ✕
              </button>
            </div>
            <div className="modal-body">
              {analysisLoading && <p>Loading results...</p>}
              {!analysisLoading && selectedAnalysis && selectedAnalysis.length === 0 && (
                <p>No analysis results available for this report.</p>
              )}
              {!analysisLoading &&
                selectedAnalysis &&
                selectedAnalysis.length > 0 &&
                selectedAnalysis.map((result, index) => (
                  <div
                    key={index}
                    className={`result-card status-${result.status?.toLowerCase()}`}
                  >
                    <div className="result-header">
                      <h3>{result.testName}</h3>
                      <span
                        className={`status-badge status-${result.status?.toLowerCase()}`}
                      >
                        {result.status}
                      </span>
                    </div>
                    <p className="result-value">
                      <strong>
                        {result.value} {result.unit}
                      </strong>
                      {result.normalRange && (
                        <span>
                          {" "}
                          (Normal: {result.normalRange.min} -{" "}
                          {result.normalRange.max})
                        </span>
                      )}
                    </p>
                    {result.recommendation && (
                      <div className="result-advice">
                        <strong>Advice:</strong> {result.recommendation}
                      </div>
                    )}
                  </div>
                ))}
            </div>
          </div>
        </div>
      )}
    </section>
  );
}

export default HistoryPage;
