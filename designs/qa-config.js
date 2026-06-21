// QuoteAssist — Tailwind CDN runtime config.
// Loaded AFTER the Tailwind CDN script so its `tailwind.config` is rewritten
// before any utility classes resolve. Adds the mist neutral scale, the teal
// accent scale, and the Inter / Familjen Grotesk pairing.

tailwind.config = {
  darkMode: 'class',
  theme: {
    extend: {
      fontFamily: {
        display: ['"Familjen Grotesk"', 'system-ui', 'sans-serif'],
        sans:    ['Inter', 'system-ui', 'sans-serif'],
        mono:    ['"JetBrains Mono"', 'ui-monospace', 'monospace'],
      },
      colors: {
        mist: {
          50:  'oklch(98.7% 0.002 197.1)',
          100: 'oklch(96.3% 0.002 197.1)',
          200: 'oklch(92.5% 0.005 214.3)',
          300: 'oklch(87.2% 0.007 219.6)',
          400: 'oklch(72.3% 0.014 214.4)',
          500: 'oklch(56% 0.021 213.5)',
          600: 'oklch(45% 0.017 213.2)',
          700: 'oklch(37.8% 0.015 216)',
          800: 'oklch(27.5% 0.011 216.9)',
          900: 'oklch(21.8% 0.008 223.9)',
          950: 'oklch(14.8% 0.004 228.8)',
        },
        teal: {
          50:  'oklch(96% 0.03 188)',
          100: 'oklch(93% 0.05 188)',
          200: 'oklch(88% 0.08 188)',
          300: 'oklch(81% 0.10 189)',
          400: 'oklch(72% 0.13 188)',
          500: 'oklch(64% 0.13 190)',
          600: 'oklch(57% 0.115 192)',
          700: 'oklch(49% 0.10 193)',
          800: 'oklch(40% 0.085 194)',
          900: 'oklch(31% 0.065 196)',
        },
      },
      boxShadow: {
        'card':  '0 1px 2px rgb(0 0 0 / 0.04)',
        'lift':  '0 12px 32px -8px rgb(0 0 0 / 0.12)',
        'pop':   '0 24px 60px -12px rgb(0 0 0 / 0.20)',
      },
      borderRadius: {
        '2.5xl': '20px',
      },
    }
  }
};
