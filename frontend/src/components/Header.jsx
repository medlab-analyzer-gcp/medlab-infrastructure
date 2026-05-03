import { useEffect, useRef, useState } from "react";
import { NavLink } from "react-router-dom";

function Header({ theme, onToggleTheme, user, onSignOut }) {
  const navClass = ({ isActive }) =>
    isActive ? "nav-link active" : "nav-link";
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef(null);

  // Get user initials from username
  const getUserInitials = () => {
    if (!user?.username) return "??";
    const name = user.username;
    return name.length >= 2
      ? name.substring(0, 2).toUpperCase()
      : name.toUpperCase();
  };

  useEffect(() => {
    if (!menuOpen) return;
    const handleClick = (event) => {
      if (menuRef.current && !menuRef.current.contains(event.target)) {
        setMenuOpen(false);
      }
    };
    window.addEventListener("click", handleClick);
    return () => window.removeEventListener("click", handleClick);
  }, [menuOpen]);

  return (
    <header className="header">
      <div className="brand-mark">
        <span className="brand-initials">ML</span>
        <div>
          <p className="brand-title">MedLab Analyzer</p>
          <span className="brand-subtitle">Understand every lab report</span>
        </div>
      </div>
      <nav className="nav">
        <NavLink to="/upload" className={navClass}>
          Upload
        </NavLink>
        <NavLink to="/history" className={navClass}>
          History
        </NavLink>
      </nav>
      <div className="header-actions">
        <button
          type="button"
          className="theme-toggle"
          onClick={onToggleTheme}
          aria-pressed={theme === "dark"}
        >
          {theme === "dark" ? "Light mode" : "Dark mode"}
        </button>
        <div className="user-menu" ref={menuRef}>
          <button
            type="button"
            className="user-chip"
            onClick={() => setMenuOpen((prev) => !prev)}
          >
            <span className="user-avatar">{getUserInitials()}</span>
            <span className="user-name">{user?.username || "User"}</span>
          </button>
          {menuOpen && (
            <div className="user-dropdown">
              <p className="dropdown-name">
                Signed in as {user?.username || "User"}
              </p>
              <button type="button">Account settings</button>
              <button type="button" onClick={onSignOut}>
                Logout
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}

export default Header;
