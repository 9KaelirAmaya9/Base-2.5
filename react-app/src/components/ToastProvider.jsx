import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

const ToastContext = createContext({
  push: () => {},
  success: () => {},
  error: () => {},
  info: () => {},
});

export const useToast = () => useContext(ToastContext);

const ToastProvider = ({ children }) => {
  const [toasts, setToasts] = useState([]);
  const nextIdRef = useRef(1);
  const timeoutRefs = useRef(new Map());

  const remove = useCallback((id) => {
    const timeoutId = timeoutRefs.current.get(id);
    if (timeoutId) {
      window.clearTimeout(timeoutId);
      timeoutRefs.current.delete(id);
    }
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const push = useCallback(
    (toast) => {
      const id = nextIdRef.current++;
      const type = toast?.type || 'info';
      const message = String(toast?.message || '').trim();
      if (!message) {
        return;
      }

      const durationMs = Number.isFinite(toast?.durationMs) ? toast.durationMs : 3500;

      setToasts((prev) => [...prev, { id, type, message }]);

      const timeoutId = window.setTimeout(
        () => {
          remove(id);
        },
        Math.max(500, durationMs)
      );

      timeoutRefs.current.set(id, timeoutId);
    },
    [remove]
  );

  useEffect(() => {
    return () => {
      timeoutRefs.current.forEach((timeoutId) => {
        window.clearTimeout(timeoutId);
      });
      timeoutRefs.current.clear();
    };
  }, []);

  const api = useMemo(
    () => ({
      push,
      success: (message, opts) => push({ ...(opts || {}), type: 'success', message }),
      error: (message, opts) => push({ ...(opts || {}), type: 'error', message }),
      info: (message, opts) => push({ ...(opts || {}), type: 'info', message }),
    }),
    [push]
  );

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div style={styles.container} aria-live="polite" aria-atomic="true">
        {toasts.map((t) => (
          <div key={t.id} style={{ ...styles.toast, ..._toastStyleForType(t.type) }}>
            <div style={styles.message}>{t.message}</div>
            <button
              type="button"
              onClick={() => remove(t.id)}
              style={styles.close}
              aria-label="Dismiss notification"
            >
              ×
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
};

const _toastStyleForType = (type) => {
  if (type === 'error') {
    return {
      background: '#fee2e2',
      color: '#991b1b',
      border: '1px solid #fecaca',
    };
  }

  if (type === 'success') {
    return {
      background: '#ffffff',
      color: '#111827',
      border: '1px solid #d1d5db',
    };
  }

  return {
    background: '#ffffff',
    color: '#111827',
    border: '1px solid #d1d5db',
  };
};

const styles = {
  container: {
    position: 'fixed',
    top: 12,
    right: 12,
    zIndex: 9999,
    display: 'flex',
    flexDirection: 'column',
    gap: 10,
    maxWidth: 360,
  },
  toast: {
    display: 'flex',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    gap: 12,
    borderRadius: 10,
    padding: '10px 12px',
    boxShadow: '0 2px 12px rgba(0, 0, 0, 0.08)',
    fontSize: 14,
  },
  message: {
    lineHeight: 1.35,
  },
  close: {
    border: 'none',
    background: 'transparent',
    cursor: 'pointer',
    fontSize: 18,
    lineHeight: 1,
    padding: 0,
    color: 'inherit',
  },
};

export default ToastProvider;
