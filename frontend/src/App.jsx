import { useEffect, useState } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import "./App.css";

import { AuthProvider, useAuth } from "./contexts/AuthContext";
import AuthPage from "./components/AuthPage";
import Header from "./components/Header";
import Footer from "./components/Footer";
import UploadPage from "./pages/UploadPage";
import HistoryPage from "./pages/HistoryPage";
import AnalyzePage from "./pages/AnalyzePage";
import NotFoundPage from "./pages/NotFoundPage";

function AppContent() {
  const [theme, setTheme] = useState("light");
  const { user, idToken, signOut } = useAuth();

  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);

  const handleToggleTheme = () => {
    setTheme((prev) => (prev === "light" ? "dark" : "light"));
  };

  // Show auth page if user is not logged in
  if (!user) {
    return <AuthPage />;
  }

  return (
    <BrowserRouter>
      <div className={`app-shell theme-${theme}`}>
        <Header
          theme={theme}
          onToggleTheme={handleToggleTheme}
          user={user}
          onSignOut={signOut}
        />
        <main className="app-main">
          <Routes>
            <Route path="/" element={<Navigate to="/upload" replace />} />
            <Route
              path="/upload"
              element={<UploadPage jwtToken={idToken} user={user} />}
            />
            <Route
              path="/history"
              element={<HistoryPage jwtToken={idToken} user={user} />}
            />
            <Route
              path="/analyze"
              element={<AnalyzePage jwtToken={idToken} user={user} />}
            />
            <Route path="*" element={<NotFoundPage />} />
          </Routes>
        </main>
        <Footer />
      </div>
    </BrowserRouter>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
