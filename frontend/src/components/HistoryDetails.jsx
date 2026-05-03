function HistoryDetails({ report }) {
  if (!report) {
    return (
      <div className="history-details empty">
        <p>Select a report to view the automated summary.</p>
      </div>
    )
  }

  return (
    <div className="history-details">
      <header>
        <p className="eyebrow">{report.id}</p>
        <h2>{report.type}</h2>
        <span>{report.collectedAt}</span>
      </header>
      <p className="impression">{report.impression}</p>
      <ul className="highlights">
        {report.highlights?.map((item) => (
          <li key={item.label}>
            <div className="highlight-head">
              <strong>{item.label}</strong>
              <span className={`state state--${item.state.toLowerCase()}`}>{item.state}</span>
            </div>
            <p className="highlight-value">{item.value}</p>
            <p className="highlight-note">{item.note}</p>
          </li>
        ))}
      </ul>
    </div>
  )
}

export default HistoryDetails
