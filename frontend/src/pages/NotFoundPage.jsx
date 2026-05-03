import { Link } from 'react-router-dom'

function NotFoundPage() {
  return (
    <section className="not-found">
      <h1>Page not found</h1>
      <p>The page you are looking for does not exist. Choose where to go next.</p>
      <div className="not-found__actions">
        <Link to="/upload">Go to upload</Link>
        <Link to="/history">See history</Link>
      </div>
    </section>
  )
}

export default NotFoundPage
