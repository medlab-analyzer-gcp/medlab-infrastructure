import UploadForm from "../components/UploadForm";

function UploadPage({ jwtToken, user }) {
  return (
    <section className="upload-page">
      <div className="page-intro">
        <p className="eyebrow">Upload report</p>
        <h1>Upload a Lab Report</h1>
        <p>
          Upload your medical lab report (PDF or image). After uploading, you
          can manually enter test values for analysis.
        </p>
      </div>
      <UploadForm jwtToken={jwtToken} user={user} />
    </section>
  );
}

export default UploadPage;
