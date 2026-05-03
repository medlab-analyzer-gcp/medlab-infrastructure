function HistoryList({ items, selectedId, onSelect }) {
  if (!items?.length) {
    return (
      <div className="history-empty">
        <p>No reports yet.</p>
        <span>Your previous analyses will appear here once a report is uploaded.</span>
      </div>
    )
  }

  return (
    <ul className="history-list">
      {items.map((entry) => (
        <li key={entry.id}>
          <button
            type="button"
            className={`history-card${selectedId === entry.id ? ' active' : ''}`}
            onClick={() => onSelect(entry)}
          >
            <div>
              <p className="eyebrow">{entry.id}</p>
              <h3>{entry.type}</h3>
            </div>
            <div className="history-meta">
              <span>{entry.collectedAt}</span>
              <p>{entry.status}</p>
            </div>
          </button>
        </li>
      ))}
    </ul>
  )
}

export default HistoryList
