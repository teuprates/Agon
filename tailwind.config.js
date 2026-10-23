/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./public/**/*.html", "./protected-pages/**/*.html", "./public/js/**/*.js"],
  theme: {
    extend: {
      fontFamily: { sans: ["Inter", "sans-serif"] },
      colors: {
        agonBlue: "#23366e", agonBg: "#F5F7FB", agonGreen: "#10B981",
        agonOrange: "#F59E0B", agonPurple: "#8B5CF6", agonCyan: "#06B6D4",
      },
      borderRadius: { "2xl": "16px" },
    },
  },
  safelist: [{ pattern: /^(bg|text|border)-(emerald|red|amber|blue)-(50|100|200|600|700)$/ }],
};
