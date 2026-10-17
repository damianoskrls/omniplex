import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './lib/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        bg: '#090A0F',
        card: '#14161F',
        border: '#1E2130',
        'border-light': '#2B2E3D',
        text: '#F5F5FA',
        muted: '#A7ABBE',
        dim: '#6B7280',
        'brand-start': '#4452D8',
        'brand-mid': '#7B3EAD',
        'brand-end': '#C52473',
        accent: '#9A9DFF',
        primary: '#4452D8',
        green: '#8DE2BB',
      },
      fontFamily: {
        sans: ['var(--font-inter)', 'system-ui', 'sans-serif'],
      },
      backgroundImage: {
        'brand-gradient': 'linear-gradient(135deg, #4452D8 0%, #7B3EAD 55%, #C52473 100%)',
        'brand-gradient-x': 'linear-gradient(90deg, #4452D8 0%, #7B3EAD 55%, #C52473 100%)',
        'card-gradient': 'linear-gradient(135deg, #14161F 0%, #1a1d2e 100%)',
        'dot-pattern': 'radial-gradient(circle, #2B2E3D 1px, transparent 1px)',
      },
      backgroundSize: {
        'dot-sm': '24px 24px',
        'dot-md': '32px 32px',
      },
      animation: {
        float: 'float 6s ease-in-out infinite',
        'pulse-slow': 'pulse 4s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        shimmer: 'shimmer 2s linear infinite',
      },
      keyframes: {
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-16px)' },
        },
        shimmer: {
          '0%': { backgroundPosition: '-200% 0' },
          '100%': { backgroundPosition: '200% 0' },
        },
      },
      boxShadow: {
        'brand-sm': '0 4px 24px rgba(68, 82, 216, 0.2)',
        'brand-md': '0 8px 40px rgba(68, 82, 216, 0.3)',
        'brand-lg': '0 16px 60px rgba(68, 82, 216, 0.4)',
        'card': '0 4px 24px rgba(0, 0, 0, 0.4)',
        'card-hover': '0 8px 40px rgba(0, 0, 0, 0.6)',
      },
    },
  },
  plugins: [],
}
export default config
