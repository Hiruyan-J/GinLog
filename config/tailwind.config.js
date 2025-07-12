// const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      fontFamily: {
//         sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
      colors: {
        'footer-color': '#c4cbc3',
      },
    },
  },
  plugins: [
    // require('@tailwindcss/forms'),
    // require('@tailwindcss/typography'),
    // require('@tailwindcss/container-queries'),
  ],
  safelist: ['alert-success', 'alert-info','alert-warning', 'alert-error'],
}
