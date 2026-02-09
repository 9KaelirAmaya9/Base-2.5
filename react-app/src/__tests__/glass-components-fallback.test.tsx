import React from 'react';
import { render, screen } from '@testing-library/react';
import { ensureBackdropSupport } from '../services/glass/supports';
import GlassCard from '../components/glass/GlassCard';

describe('Glass components fallback when backdrop-filter unsupported', () => {
  afterEach(() => {
    document.documentElement.classList.remove('no-backdrop');
  });

  it('adds no-backdrop root class and renders components', () => {
    global.CSS = { supports: () => false } as any;
    ensureBackdropSupport();
    render(
      <GlassCard>
        <button className="glass glass-interactive">Click</button>
      </GlassCard>
    );
    expect(document.documentElement.classList.contains('no-backdrop')).toBe(true);
    expect(screen.getByTestId('glass-card')).toBeInTheDocument();
  });
});
