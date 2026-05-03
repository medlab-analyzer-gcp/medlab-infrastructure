import { useState } from "react";
import { uploadReport } from "../utils/api";

function UploadForm({ jwtToken, user }) {
  const [file, setFile] = useState(null);
  const [fileLabel, setFileLabel] = useState("");
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  const handleFileChange = (event) => {
    const nextFile = event.target.files?.[0];
    setFile(nextFile);
    setFileLabel(nextFile ? nextFile.name : "");
    setMessage("");
  };

  const fileToBase64 = (file) => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = () => {
        const base64String = reader.result.split(",")[1];
        resolve(base64String);
      };
      reader.onerror = (error) => reject(error);
    });
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    if (busy || !file || !jwtToken) return;

    setBusy(true);
    setMessage("");

    try {
      const base64File = await fileToBase64(file);

      const data = await uploadReport(
        jwtToken,
        user.userId,
        file.name,
        file.type,
        base64File
      );

      setMessage("✓ Report uploaded successfully!");
      setFile(null);
      setFileLabel("");
      setNotes("");
    } catch (error) {
      setMessage(`Error: ${error.message || "Failed to upload report"}`);
    } finally {
      setBusy(false);
    }
  };

  return (
    <form className="upload-form" onSubmit={handleSubmit}>
      <label className="dropzone">
        <input
          type="file"
          accept="application/pdf,image/*"
          onChange={handleFileChange}
          required
        />
        <span className="dropzone-title">Select PDF or Image</span>
        <p>Tap to browse or drag a lab report</p>
        {fileLabel && <p className="file-label">Selected: {fileLabel}</p>}
      </label>

      <button type="submit" disabled={busy || !jwtToken}>
        {busy ? "Uploading…" : "Upload Report"}
      </button>

      {message && (
        <p
          className={
            message.startsWith("✓") ? "success-message" : "error-message"
          }
        >
          {message}
        </p>
      )}
    </form>
  );
}

export default UploadForm;
