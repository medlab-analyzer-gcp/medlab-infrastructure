import { useState, useEffect, useRef } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import { io } from "socket.io-client";
import { analyzeRequest, WS_SERVICE_URL } from "../utils/api";
import { setSocket } from "../utils/socketManager";

const AVAILABLE_TESTS = [
  { name: "Hemoglobin", unit: "g/dL" },
  { name: "WBC", unit: "10^3/uL" },
  { name: "RBC", unit: "10^6/uL" },
  { name: "Platelets", unit: "10^3/uL" },
  { name: "Hematocrit", unit: "%" },
  { name: "Glucose", unit: "mg/dL" },
  { name: "Creatinine", unit: "mg/dL" },
  { name: "BUN", unit: "mg/dL" },
  { name: "Sodium", unit: "mEq/L" },
  { name: "Potassium", unit: "mEq/L" },
  { name: "Calcium", unit: "mg/dL" },
  { name: "Cholesterol", unit: "mg/dL" },
  { name: "LDL", unit: "mg/dL" },
  { name: "HDL", unit: "mg/dL" },
  { name: "Triglycerides", unit: "mg/dL" },
  { name: "ALT", unit: "U/L" },
  { name: "AST", unit: "U/L" },
  { name: "Bilirubin", unit: "mg/dL" },
  { name: "TSH", unit: "mIU/L" },
];

function AnalyzePage({ jwtToken, user }) {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const reportId = searchParams.get("reportId");

  const [gender, setGender] = useState("male");
  const [age, setAge] = useState("");
  const [testResults, setTestResults] = useState([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [analyzedResults, setAnalyzedResults] = useState(null);
  const [testFilters, setTestFilters] = useState([]);
  const [openDropdown, setOpenDropdown] = useState(null);
  const dropdownRefs = useRef([]);

  useEffect(() => {
    if (!reportId) {
      setMessage("Error: No report ID provided");
    }
  }, [reportId]);

  const addTest = () => {
    setTestResults((prev) => [...prev, { testName: "", value: "", unit: "" }]);
    setTestFilters((prev) => [...prev, ""]);
  };

  const removeTest = (index) => {
    setTestResults((prev) => prev.filter((_, i) => i !== index));
    setTestFilters((prev) => prev.filter((_, i) => i !== index));
    setOpenDropdown((prev) => {
      if (prev === null) return null;
      if (prev === index) return null;
      if (prev > index) return prev - 1;
      return prev;
    });
  };

  const updateTest = (index, field, value) => {
    const updated = [...testResults];
    updated[index][field] = value;

    if (field === "testName") {
      const test = AVAILABLE_TESTS.find((t) => t.name === value);
      if (test) {
        updated[index].unit = test.unit;
      }
    }

    setTestResults(updated);
  };

  const handleFilterChange = (index, value) => {
    setTestFilters((prev) => {
      const next = [...prev];
      next[index] = value;
      return next;
    });
  };

  const handleSelectTest = (index, test) => {
    updateTest(index, "testName", test.name);
    setTestFilters((prev) => {
      const next = [...prev];
      next[index] = "";
      return next;
    });
    setOpenDropdown(null);
  };

  const toggleDropdown = (index) => {
    setOpenDropdown((prev) => (prev === index ? null : index));
  };

  useEffect(() => {
    if (openDropdown === null) return;

    const handleClickOutside = (event) => {
      const currentRef = dropdownRefs.current[openDropdown];
      if (currentRef && !currentRef.contains(event.target)) {
        setOpenDropdown(null);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [openDropdown]);

  useEffect(() => {
    dropdownRefs.current = dropdownRefs.current.slice(0, testResults.length);
  }, [testResults.length]);

  const handleAnalyze = async () => {
    if (!reportId || testResults.length === 0) {
      setMessage("Please add at least one test result");
      return;
    }

    const validTests = testResults.filter((t) => t.testName && t.value);
    if (validTests.length === 0) {
      setMessage("Please fill in test names and values");
      return;
    }

    setBusy(true);
    setMessage("");
    setAnalyzedResults(null);

    try {
      const testResultsObj = Object.fromEntries(
        validTests.map((t) => [t.testName, parseFloat(t.value)])
      );

      // Try to open WebSocket — non-blocking, analysis proceeds even if WS fails
      // (Cloud Run cold starts can take longer than any reasonable timeout)
      await new Promise((resolve) => {
        const socket = io(WS_SERVICE_URL, {
          transports: ["websocket", "polling"],
        });

        const timeout = setTimeout(() => {
          socket.disconnect();
          resolve(false);
        }, 15000);

        socket.on("connect", () => {
          socket.emit("subscribe", user.userId);
        });

        socket.on("subscribed", () => {
          clearTimeout(timeout);
          setSocket(socket);
          resolve(true);
        });

        socket.on("connect_error", () => {
          clearTimeout(timeout);
          resolve(false);
        });
      });

      // Queue analysis regardless of WebSocket status
      await analyzeRequest(
        jwtToken,
        reportId,
        user.userId,
        testResultsObj,
        { gender, age: parseInt(age) || 30 }
      );

      setMessage("✓ Analysis queued! Going to History...");
      navigate("/history");

    } catch (error) {
      setMessage(`Error: ${error.message || "Failed to queue analysis"}`);
    } finally {
      setBusy(false);
    }
  };

  if (!reportId) {
    return (
      <section className="analyze-page">
        <div className="page-intro">
          <p className="eyebrow">Analyze</p>
          <h1>No Report Selected</h1>
          <p>Please select a report from the History page to analyze.</p>
          <button onClick={() => navigate("/history")}>Go to History</button>
        </div>
      </section>
    );
  }

  return (
    <section className="analyze-page">
      <div className="analyze-form">
        <div className="page-intro">
          <p className="eyebrow">Analyze</p>
          <h1>Manual Test Entry</h1>
          <p>
            Enter your lab test values manually for analysis. Report ID:{" "}
            {reportId}
          </p>
        </div>
        <div className="gender-select">
          <label>
            Age:
            <input
              type="number"
              min="1"
              max="120"
              placeholder="Age"
              value={age}
              onChange={(e) => setAge(e.target.value)}
              style={{ width: "80px", marginLeft: "8px" }}
            />
          </label>
        </div>
        <div className="gender-select">
          <label>
            <input
              type="radio"
              value="male"
              checked={gender === "male"}
              onChange={(e) => setGender(e.target.value)}
            />
            Male
          </label>
          <label>
            <input
              type="radio"
              value="female"
              checked={gender === "female"}
              onChange={(e) => setGender(e.target.value)}
            />
            Female
          </label>
        </div>

        {testResults.map((test, index) => {
          const filterValue = (testFilters[index] || "").toLowerCase().trim();
          const filteredTests = AVAILABLE_TESTS.filter((t) =>
            t.name.toLowerCase().includes(filterValue)
          );

          return (
            <div key={index} className="test-input-row">
              <div
                className={`test-select${openDropdown === index ? " open" : ""}`}
                ref={(el) => {
                  dropdownRefs.current[index] = el;
                }}
              >
                <button
                  type="button"
                  className="test-select__trigger"
                  onClick={() => toggleDropdown(index)}
                  aria-haspopup="listbox"
                  aria-expanded={openDropdown === index}
                >
                  {test.testName || "Select test"}
                </button>
                {openDropdown === index && (
                  <div className="test-select__dropdown">
                    <input
                      type="text"
                      placeholder="Search tests"
                      value={testFilters[index] || ""}
                      onChange={(e) => handleFilterChange(index, e.target.value)}
                      className="test-select__search"
                      autoFocus
                    />
                    <div className="test-select__options" role="listbox">
                      {filteredTests.length === 0 && (
                        <div className="test-select__empty">No matches</div>
                      )}
                      {filteredTests.map((t) => (
                        <button
                          type="button"
                          key={t.name}
                          className="test-select__option"
                          onClick={() => handleSelectTest(index, t)}
                        >
                          <span>{t.name}</span>
                          <small>{t.unit}</small>
                        </button>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              <input
                type="number"
                step="0.01"
                placeholder="Value"
                value={test.value}
                onChange={(e) => updateTest(index, "value", e.target.value)}
              />

              <input
                type="text"
                placeholder="Unit"
                value={test.unit}
                onChange={(e) => updateTest(index, "unit", e.target.value)}
                readOnly
              />

              <button
                type="button"
                onClick={() => removeTest(index)}
                className="btn-remove"
              >
                Remove
              </button>
            </div>
          );
        })}

        <div className="form-actions">
          <button type="button" onClick={addTest} className="btn-secondary">
            + Add Test
          </button>
          <button
            type="button"
            onClick={handleAnalyze}
            disabled={busy || !jwtToken}
            className="btn-primary"
          >
            {busy ? "Analyzing..." : "Analyze Results"}
          </button>
        </div>

        {message && (
          <p
            className={
              message.startsWith("✓") ? "success-message" : "error-message"
            }
          >
            {message}
          </p>
        )}

        {analyzedResults && (
          <button
            type="button"
            onClick={() => navigate("/history")}
            className="btn-secondary"
            style={{ marginTop: "1rem" }}
          >
            Go to History
          </button>
        )}
      </div>

      {analyzedResults && (
        <div className="analysis-results">
          <h2>Analysis Results</h2>
          {analyzedResults.map((result, index) => (
            <div
              key={index}
              className={`result-card status-${result.status.toLowerCase()}`}
            >
              <div className="result-header">
                <h3>{result.testName}</h3>
                <span
                  className={`status-badge status-${result.status.toLowerCase()}`}
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
      )}
    </section>
  );
}

export default AnalyzePage;
