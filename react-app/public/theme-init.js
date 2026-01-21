(function () {
  try {
    // Apply initial theme class before React mounts.
    // Precedence: theme cookie -> prefers-color-scheme -> light.
    var cookieMatch = document.cookie.match(/(?:^|; )theme=([^;]+)/);
    var cookieTheme = cookieMatch ? decodeURIComponent(cookieMatch[1]) : null;

    var prefersDark =
      window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;

    var theme = cookieTheme || (prefersDark ? 'dark' : 'light');

    var root = document.documentElement;
    if (theme === 'dark') root.classList.add('dark');
    else root.classList.remove('dark');
  } catch (_e) {
    // Never block app startup due to theme init.
  }
})();
