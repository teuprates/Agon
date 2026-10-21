/* ============================================================
   AGON — Shared JavaScript
   Theme toggle, sidebar, profile modal, header interactions
   ============================================================ */

document.addEventListener('DOMContentLoaded', function () {

  // ─── Theme Management ────────────────────────────────────
  const savedTheme = localStorage.getItem('agon-theme') || 'light';
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeIcons(savedTheme);
  updateThemeLogos(savedTheme);

  document.querySelectorAll('.theme-toggle').forEach(btn => {
    btn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme');
      const next = current === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('agon-theme', next);
      updateThemeIcons(next);
      updateThemeLogos(next);
      
      // Dispatch custom event for charts or dynamic components to react
      window.dispatchEvent(new CustomEvent('agonThemeChanged', { detail: { theme: next } }));
    });
  });

  function updateThemeIcons(theme) {
    document.querySelectorAll('.theme-toggle').forEach(btn => {
      const icon = btn.querySelector('i');
      if (icon) {
        icon.className = theme === 'dark'
          ? 'fa-solid fa-sun'
          : 'fa-solid fa-moon';
      }
    });
    // Update the toggle switch in profile modal settings
    const themeSwitch = document.getElementById('theme-switch');
    if (themeSwitch) {
      themeSwitch.checked = theme === 'dark';
    }
  }

  function updateThemeLogos(theme) {
    const isDark = theme === 'dark';

    // 1. Swap all logo images between dark (agon-white.png) and light (AGON png.png)
    const logoImgs = document.querySelectorAll('img[alt="AGON"], img[alt="Agon"], img[alt="Logo"], .agon-logo-img');
    logoImgs.forEach(img => {
      const currentSrc = img.getAttribute('src');
      if (!currentSrc) return;
      if (isDark) {
        if (currentSrc.includes('AGON%20png.png') || currentSrc.includes('AGON png.png')) {
          img.src = currentSrc.replace(/AGON(%20|\s)png\.png/, 'agon-white.png');
        }
      } else {
        if (currentSrc.includes('agon-white.png')) {
          img.src = currentSrc.replace('agon-white.png', 'AGON png.png');
        }
      }
    });

    // 2. Ensure brand text next to the logo is white in dark mode and agon blue in light mode
    document.querySelectorAll('.sidebar a span, header a span, .auth-card a span, a.group span, .agon-brand-text').forEach(span => {
      const txt = span.textContent.trim().toUpperCase();
      if (txt === 'AGON') {
        span.style.color = isDark ? '#FFFFFF' : 'var(--color-blue)';
      }
    });
  }

  // Theme switch inside profile modal
  const themeSwitch = document.getElementById('theme-switch');
  if (themeSwitch) {
    themeSwitch.addEventListener('change', () => {
      const next = themeSwitch.checked ? 'dark' : 'light';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('agon-theme', next);
      updateThemeIcons(next);
      updateThemeLogos(next);
      window.dispatchEvent(new CustomEvent('agonThemeChanged', { detail: { theme: next } }));
    });
  }

  // ─── Sidebar Active State ─────────────────────────────────
  const currentPage = window.location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('.nav-item').forEach(item => {
    const href = item.getAttribute('href');
    if (href === currentPage || (currentPage === '' && href === 'index.html')) {
      item.classList.add('active');
    }
  });

  // ─── Mobile Sidebar Toggle ───────────────────────────────
  const sidebar = document.querySelector('.sidebar');
  const sidebarOverlay = document.querySelector('.sidebar-overlay');
  const menuBtn = document.getElementById('mobile-menu-btn');

  if (menuBtn && sidebar) {
    menuBtn.addEventListener('click', () => {
      sidebar.classList.toggle('open');
      if (sidebarOverlay) sidebarOverlay.classList.toggle('active');
    });
  }
  if (sidebarOverlay) {
    sidebarOverlay.addEventListener('click', () => {
      sidebar.classList.remove('open');
      sidebarOverlay.classList.remove('active');
    });
  }

  // ─── Profile Modal ────────────────────────────────────────
  const modalOverlay = document.getElementById('profile-modal');
  const modalOpenBtns = document.querySelectorAll('.open-profile-modal');
  const modalCloseBtn = document.getElementById('modal-close-btn');

  function openModal() {
    if (modalOverlay) {
      modalOverlay.classList.add('active');
      document.body.style.overflow = 'hidden';
    }
  }
  function closeModal() {
    if (modalOverlay) {
      modalOverlay.classList.remove('active');
      document.body.style.overflow = '';
    }
  }

  modalOpenBtns.forEach(btn => btn.addEventListener('click', openModal));
  if (modalCloseBtn) modalCloseBtn.addEventListener('click', closeModal);
  if (modalOverlay) {
    modalOverlay.addEventListener('click', (e) => {
      if (e.target === modalOverlay) closeModal();
    });
  }
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeModal();
  });

  // Modal Tabs
  document.querySelectorAll('.modal-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      const target = tab.dataset.tab;
      document.querySelectorAll('.modal-tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.modal-tab-content').forEach(c => c.classList.remove('active'));
      tab.classList.add('active');
      const content = document.getElementById('tab-' + target);
      if (content) content.classList.add('active');
    });
  });

  // ─── Notification Dropdown (Simple) ──────────────────────
  const notifBtn = document.getElementById('notif-btn');
  const notifDropdown = document.getElementById('notif-dropdown');
  if (notifBtn && notifDropdown) {
    notifBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      notifDropdown.classList.toggle('hidden');
    });
    document.addEventListener('click', () => {
      notifDropdown.classList.add('hidden');
    });
  }
});

/* ─── Chart.js Theme Helper ─────────────────────────────────
   Call this before creating charts to get theme-aware colors */
function getChartColors() {
  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  return {
    grid: isDark ? '#334155' : '#E5E7EB',
    text: isDark ? '#94A3B8' : '#6B7280',
    blue: isDark ? '#60A5FA' : '#23366e',
    green: isDark ? '#34D399' : '#10B981',
    orange: isDark ? '#FBBF24' : '#F59E0B',
    purple: isDark ? '#A78BFA' : '#8B5CF6',
    cyan: isDark ? '#38BDF8' : '#06B6D4',
    grayLine: isDark ? '#475569' : '#D1D5DB',
    bgBlue: isDark ? 'rgba(96, 165, 250, 0.2)' : 'rgba(35, 54, 110, 0.1)',
    bgGreen: isDark ? 'rgba(52, 211, 153, 0.2)' : 'rgba(16, 185, 129, 0.1)',
    pointBg: isDark ? '#1E293B' : '#FFFFFF',
  };
}
